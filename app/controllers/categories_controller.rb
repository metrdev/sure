class CategoriesController < ApplicationController
  before_action :set_category, only: %i[edit update destroy]
  before_action :authorize_category_management, only: %i[edit update destroy]
  before_action :require_admin!, only: %i[merge perform_merge bootstrap]
  before_action :set_categories, only: %i[update edit]
  before_action :set_transaction, only: :create

  def index
    @categories = Current.family.categories.visible_to(Current.user).alphabetically_by_hierarchy.to_a
    @category_groups = Category::Group.for(@categories)
    @category_ids_with_transactions = Category.ids_with_transactions(
      family: Current.family,
      category_ids: @categories.map(&:id)
    )

    render layout: "settings"
  end

  def new
    @category = Current.family.categories.new(
      color: Category::COLORS.sample,
      sharing_mode: Current.user.admin? ? "aligned" : "private",
      owner: Current.user.admin? ? nil : Current.user
    )
    set_categories
  end

  def merge
    @categories = Current.family.categories.visible_to(Current.user).where(system_key: nil).alphabetically

    render layout: turbo_frame_request? ? false : "settings"
  end

  def create
    @category = Current.family.categories.new(category_params)
    apply_category_ownership(@category)

    if @category.save
      sync_budgets
      @transaction.update(category_id: @category.id) if @transaction

      flash[:notice] = t(".success")

      redirect_target_url = request.referer || categories_path
      respond_to do |format|
        format.html { redirect_back_or_to categories_path, notice: t(".success") }
        format.turbo_stream { render turbo_stream: turbo_stream.action(:redirect, redirect_target_url) }
      end
    else
      set_categories
      render :new, status: :unprocessable_entity
    end
  end

  def edit
  end

  def update
    attributes = category_params
    if transition_confirmation_required?(attributes)
      @transition_attributes = attributes.to_h
      @preview = Category::ChangeSharingMode.preview(
        category: @category,
        attributes: attributes,
        owner: Current.user
      )
      render :confirm_transition
      return
    end

    @category = Category::ChangeSharingMode.call!(
      category: @category,
      attributes: attributes,
      owner: Current.user
    )

    flash[:notice] = t(".success")

    redirect_target_url = @category ? (request.referer || categories_path) : categories_path
    respond_to do |format|
      format.html do
        if @category
          redirect_back_or_to categories_path, notice: t(".success")
        else
          redirect_to categories_path, notice: t(".success")
        end
      end
      format.turbo_stream { render turbo_stream: turbo_stream.action(:redirect, redirect_target_url) }
    end
  rescue ActiveRecord::RecordInvalid => error
    @category = error.record
    set_categories
    render :edit, status: :unprocessable_entity
  end

  def destroy
    if @category.money_transfers?
      redirect_back_or_to categories_path, alert: t("categories.destroy.system_category", default: "Системную категорию удалить нельзя")
      return
    end

    @category.destroy
    sync_budgets

    redirect_back_or_to categories_path, notice: t(".success")
  end

  def destroy_all
    scope = Current.user.admin? ? Current.family.categories.visible_to(Current.user) : Current.family.categories.private_for(Current.user)
    scope.where(system_key: nil).to_a.sort_by { |category| category.parent_id.present? ? 0 : 1 }.each(&:destroy!)
    sync_budgets
    redirect_back_or_to categories_path, notice: t(".success")
  end

  def bootstrap
    Current.family.categories.bootstrap!
    sync_budgets

    redirect_back_or_to categories_path, notice: t(".success")
  end

  def perform_merge
    permitted_params = category_merge_params

    if permitted_params[:target_id].present? && Array(permitted_params[:source_ids]).include?(permitted_params[:target_id])
      return redirect_to merge_categories_path, alert: t(".target_selected_as_source")
    end

    visible_categories = Current.family.categories.visible_to(Current.user)
    target = visible_categories.find_by(id: permitted_params[:target_id])
    return redirect_to merge_categories_path, alert: t(".target_not_found") unless target

    sources = visible_categories.where(id: permitted_params[:source_ids])
    return redirect_to merge_categories_path, alert: t(".invalid_categories") unless sources.any?
    return redirect_to merge_categories_path, alert: t(".invalid_categories") if target.money_transfers? || sources.any?(&:money_transfers?)

    merger = Category::Merger.new(family: Current.family, target_category: target, source_categories: sources)
    return redirect_to merge_categories_path, alert: t(".no_categories_selected") unless merger.merge!
    sync_budgets

    redirect_to categories_path, notice: t(".success", count: merger.merged_count)
  rescue Category::Merger::UnauthorizedCategoryError => e
    redirect_to merge_categories_path, alert: e.message
  rescue ActiveRecord::RecordInvalid, ActiveRecord::RecordNotDestroyed => e
    redirect_to merge_categories_path, alert: record_error_message(e)
  end

  private
    def set_category
      @category = Current.family.categories.visible_to(Current.user).find(params[:id])
    end

    def set_categories
      @categories = unless @category.parent?
        parent_scope = Current.family.categories.visible_to(Current.user).alphabetically.roots.where.not(id: @category.id)
        Current.user.admin? ? parent_scope : parent_scope.private_for(Current.user)
      else
        []
      end
    end

    def set_transaction
      if params[:transaction_id].present?
        @transaction = Current.family.transactions
          .joins(entry: :account)
          .merge(Account.accessible_by(Current.user))
          .find(params[:transaction_id])
      end
    end

    def category_params
      permitted = [ :name, :color, :parent_id, :lucide_icon ]
      permitted.concat([ :sharing_mode, :sharing_started_on ]) if Current.user.admin?
      permitted = [ :name, :color, :lucide_icon ] if @category&.money_transfers?
      attributes = params.require(:category).permit(*permitted)
      if attributes[:sharing_started_on].present?
        attributes[:sharing_started_on] = parse_family_date(attributes[:sharing_started_on])
      end
      attributes
    end

    def apply_category_ownership(category)
      if category.parent_id.present? && !Current.user.admin?
        category.sharing_mode = nil
        category.owner = nil
        category.sharing_started_on = nil
      elsif Current.user.admin?
        if category.sharing_mode.blank?
          category.owner = nil
          category.sharing_started_on = nil
        else
          category.owner = category.sharing_mode == "private" ? Current.user : nil
        end
      else
        category.sharing_mode = "private"
        category.owner = Current.user
        category.sharing_started_on = nil
      end
    end

    def authorize_category_management
      return if Current.user.admin? || (@category.private? && @category.effective_owner_id == Current.user.id)

      redirect_to categories_path, alert: t("accounts.not_authorized")
    end

    def transition_confirmation_required?(attributes)
      return false unless Current.user.admin?
      return false if params[:confirm_transition] == "1"
      return false unless attributes.key?(:sharing_mode)

      target_mode = attributes[:sharing_mode].presence || @category.parent&.effective_sharing_mode
      target_mode != @category.effective_sharing_mode
    end

    def require_admin!
      return if Current.user.admin?

      redirect_to categories_path, alert: t("accounts.not_authorized")
    end

    def category_merge_params
      params.permit(:target_id, source_ids: [])
    end

    def record_error_message(error)
      record = error.respond_to?(:record) ? error.record : nil
      record&.errors&.full_messages&.to_sentence.presence || error.message
    end

    def sync_budgets
      Current.family.budgets.find_each(&:sync_budget_categories)
    end
end
