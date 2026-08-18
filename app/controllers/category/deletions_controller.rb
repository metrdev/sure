class Category::DeletionsController < ApplicationController
  before_action :set_category
  before_action :authorize_category_management
  before_action :set_replacement_category, only: :create

  def new
    @replacement_categories = visible_categories.where.not(id: @category.id).alphabetically_by_hierarchy
  end

  def create
    @category.replace_and_destroy! @replacement_category
    Current.family.budgets.find_each(&:sync_budget_categories)

    redirect_back_or_to transactions_path, notice: t(".success")
  rescue ArgumentError => error
    redirect_to new_category_deletion_path(@category), alert: error.message
  end

  private
    def set_category
      @category = manageable_categories.find(params[:category_id])
    end

    def set_replacement_category
      if params[:replacement_category_id].present?
        @replacement_category = visible_categories.find(params[:replacement_category_id])
      end
    end

    def manageable_categories
      Current.user.admin? ? Current.family.categories.visible_to(Current.user) : Current.family.categories.private_for(Current.user)
    end

    def visible_categories
      Current.family.categories.visible_to(Current.user)
    end

    def authorize_category_management
      return if Current.user.admin? || (@category.private? && @category.effective_owner_id == Current.user.id)

      raise ActiveRecord::RecordNotFound
    end
end
