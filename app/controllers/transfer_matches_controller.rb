class TransferMatchesController < ApplicationController
  before_action :set_entry

  def new
    @accounts = target_accounts
    @transfer_match_candidates = @entry.transaction.transfer_match_candidates.select do |candidate|
      other_entry = @entry.amount.positive? ? candidate.inflow_transaction.entry : candidate.outflow_transaction.entry
      !@family_transfer_mirror || other_entry.account.owner_id == Current.user.id
    end
  end

  def create
    return unless @family_transfer_mirror || require_account_permission!(@entry.account, redirect_path: transactions_path)

    target_account = resolve_target_account
    return unless require_account_permission!(target_account, redirect_path: transactions_path)

    @transfer = build_transfer
    Transfer.transaction do
      @transfer.save!

      if @transfer.family_transfer?
        @transfer.outflow_transaction.update!(kind: "standard")
        @transfer.inflow_transaction.update!(kind: "standard")
      else
        # Use DESTINATION (inflow) account for kind, matching Transfer::Creator logic
        destination_account = @transfer.inflow_transaction.entry.account
        outflow_kind = Transfer.kind_for_account(destination_account)
        outflow_attrs = { kind: outflow_kind }

        if outflow_kind == "investment_contribution"
          category = destination_account.family.investment_contributions_category
          outflow_attrs[:category] = category if category.present? && @transfer.outflow_transaction.category_id.blank?
        end

        @transfer.outflow_transaction.update!(outflow_attrs)
        @transfer.inflow_transaction.update!(kind: "funds_movement")
      end
    end

    @transfer.sync_account_later

    redirect_back_or_to transactions_path, notice: t(".success")
  end

  private
    def set_entry
      @entry = Current.accessible_entries.find_by(id: params[:transaction_id])
      return @family_transfer_mirror = false if @entry

      transaction = Transaction.readable_by(Current.user).find(params[:transaction_id])
      @family_transfer_mirror = transaction.family_transfer_mirror_for?(Current.user)
      raise ActiveRecord::RecordNotFound unless @family_transfer_mirror

      @entry = transaction.entry
    end

    def transfer_match_params
      params.require(:transfer_match).permit(:method, :matched_entry_id, :target_account_id)
    end

    def resolve_target_account
      if transfer_match_params[:method] == "new"
        target_accounts.find(transfer_match_params[:target_account_id])
      else
        Current.accessible_entries.find(transfer_match_params[:matched_entry_id]).account
      end
    end

    def build_transfer
      if transfer_match_params[:method] == "new"
        target_account = target_accounts.find(transfer_match_params[:target_account_id])

        missing_transaction = Transaction.new(
          category: (@entry.account.family.money_transfers_category if @family_transfer_mirror),
          family_counterparty_user: (@entry.account.owner if @family_transfer_mirror),
          entry: target_account.entries.build(
            amount: @entry.amount * -1,
            currency: @entry.currency,
            date: @entry.date,
            name: @family_transfer_mirror ? @entry.transaction.family_transfer_name_for(Current.user) : "Transfer to #{@entry.amount.negative? ? @entry.account.name : target_account.name}",
            user_modified: true,
          )
        )

        transfer = Transfer.find_or_initialize_by(
          inflow_transaction: @entry.amount.positive? ? missing_transaction : @entry.transaction,
          outflow_transaction: @entry.amount.positive? ? @entry.transaction : missing_transaction
        )
        transfer.status = "confirmed"
        transfer
      else
        target_transaction = Current.accessible_entries.find(transfer_match_params[:matched_entry_id])
        if @family_transfer_mirror
          target_transaction.transaction.update!(
            category: @entry.account.family.money_transfers_category,
            family_counterparty_user: @entry.account.owner
          )
        end

        transfer = Transfer.find_or_initialize_by(
          inflow_transaction: @entry.amount.negative? ? @entry.transaction : target_transaction.transaction,
          outflow_transaction: @entry.amount.negative? ? target_transaction.transaction : @entry.transaction
        )
        transfer.status = "confirmed"
        transfer
      end
    end

    def recipient_accounts
      Current.family.accounts
        .writable_by(Current.user)
        .visible
        .where(owner_id: Current.user.id)
        .where.not(id: @entry.account_id)
        .alphabetically
    end

    def target_accounts
      return recipient_accounts if @family_transfer_mirror

      accessible_accounts.visible.where.not(id: @entry.account_id).alphabetically
    end
end
