module EntryableResource
  extend ActiveSupport::Concern

  included do
    include StreamExtensions, ActionView::RecordIdentifier

    before_action :set_readable_entry, only: :show
    before_action :set_entry, only: %i[update destroy]

    helper_method :can_edit_entry?, :can_annotate_entry?, :category_only_transaction_access?
  end

  def show
  end

  def new
    account = accessible_accounts.find_by(id: params[:account_id])

    @entry = Current.family.entries.new(
      account: account,
      currency: account ? account.currency : Current.family.currency,
      entryable: entryable
    )
  end

  def create
    raise NotImplementedError, "Entryable resources must implement #create"
  end

  def update
    raise NotImplementedError, "Entryable resources must implement #update"
  end

  def destroy
    return unless require_account_permission!(@entry.account)

    @entry.destroy!
    @entry.sync_account_later

    redirect_back_or_to account_path(@entry.account), notice: t("account.entries.destroy.success")
  end

  private
    def entryable
      controller_name.classify.constantize.new
    end

    def set_entry
      @entry = Current.family.entries
                 .joins(:account)
                 .merge(Account.accessible_by(Current.user))
                 .find(params[:id])
    end

    def set_readable_entry
      if controller_name == "transactions"
        transaction = Transaction.readable_by(Current.user).find_by(id: params[:id])
        transaction ||= Transaction.readable_by(Current.user).joins(:entry).find_by(entries: { id: params[:id] })
        raise ActiveRecord::RecordNotFound unless transaction

        @entry = transaction.entry
      else
        set_entry
      end
    end

    def entry_permission
      @entry_permission ||= @entry&.account&.permission_for(Current.user)
    end

    def can_edit_entry?
      entry_permission.in?([ :owner, :full_control ])
    end

    def can_annotate_entry?
      entry_permission.in?([ :owner, :full_control, :read_write ])
    end

    def category_only_transaction_access?(entry = @entry)
      entry&.transaction? && entry.account.permission_for(Current.user).nil?
    end
end
