# frozen_string_literal: true

class Api::V1::CategoriesController < Api::V1::BaseController
  include Pagy::Backend

  before_action :ensure_read_scope, only: %i[index show]
  before_action :ensure_write_scope, only: :create
  before_action :set_category, only: :show

  def index
    family = current_resource_owner.family
    @category_viewer = current_resource_owner
    categories_query = family.categories.visible_to(current_resource_owner).includes(:parent, :subcategories).alphabetically

    # Apply filters
    categories_query = apply_filters(categories_query)

    # Handle pagination with Pagy
    @pagy, @categories = pagy(
      categories_query,
      page: safe_page_param,
      limit: safe_per_page_param
    )

    @per_page = safe_per_page_param

    render :index
  rescue => e
    Rails.logger.error "CategoriesController#index error: #{e.message}"
    Rails.logger.error e.backtrace.join("\n")

    render json: {
      error: "internal_server_error",
      message: "An unexpected error occurred"
    }, status: :internal_server_error
  end

  def show
    @category_viewer = current_resource_owner
    render :show
  rescue => e
    Rails.logger.error "CategoriesController#show error: #{e.message}"
    Rails.logger.error e.backtrace.join("\n")

    render json: {
      error: "internal_server_error",
      message: "An unexpected error occurred"
    }, status: :internal_server_error
  end

  def create
    family = current_resource_owner.family
    attrs = category_params

    visible_parents = family.categories.visible_to(current_resource_owner)
    visible_parents = visible_parents.private_for(current_resource_owner) unless current_resource_owner.admin?
    if attrs[:parent_id].present? && !visible_parents.exists?(id: attrs[:parent_id])
      return render json: {
        error: "unprocessable_entity",
        message: "Parent must be a category in your family"
      }, status: :unprocessable_entity
    end

    @category = family.categories.new(attrs)
    if @category.parent_id.present? && !current_resource_owner.admin?
      @category.sharing_mode = nil
      @category.owner = nil
      @category.sharing_started_on = nil
    elsif current_resource_owner.admin?
      if @category.sharing_mode.blank? && @category.parent_id.blank?
        @category.sharing_mode = "aligned"
      end
      if @category.sharing_mode.blank?
        @category.owner = nil
        @category.sharing_started_on = nil
      else
        @category.owner = @category.sharing_mode == "private" ? current_resource_owner : nil
      end
    else
      @category.sharing_mode = "private"
      @category.owner = current_resource_owner
    end
    @category.lucide_icon = Category.suggested_icon(@category.name) if @category.lucide_icon.blank?

    if @category.save
      family.budgets.find_each(&:sync_budget_categories)
      @category_viewer = current_resource_owner
      render :show, status: :created
    else
      render json: {
        error: "unprocessable_entity",
        message: @category.errors.full_messages.join(", ")
      }, status: :unprocessable_entity
    end
  end

  private

    def set_category
      family = current_resource_owner.family
      @category = family.categories.visible_to(current_resource_owner).includes(:parent, :subcategories).find(params[:id])
    rescue ActiveRecord::RecordNotFound
      render json: {
        error: "not_found",
        message: "Category not found"
      }, status: :not_found
    end

    def ensure_read_scope
      authorize_scope!(:read)
    end

    def ensure_write_scope
      authorize_scope!(:read_write)
    end

    def category_params
      fields = [ :name, :color, :icon, :parent_id ]
      fields.concat([ :sharing_mode, :sharing_started_on ]) if current_resource_owner.admin?
      permitted = params.require(:category).permit(*fields)
      icon = permitted.delete(:icon)
      permitted[:lucide_icon] = icon if icon.present?
      permitted
    end

    def apply_filters(query)
      # Filter for root categories only (no parent)
      if params[:roots_only].present? && ActiveModel::Type::Boolean.new.cast(params[:roots_only])
        query = query.roots
      end

      # Filter by parent_id
      if params[:parent_id].present?
        query = query.where(parent_id: params[:parent_id])
      end

      query
    end

    def safe_page_param
      page = params[:page].to_i
      page > 0 ? page : 1
    end

    def safe_per_page_param
      per_page = params[:per_page].to_i

      case per_page
      when 1..100
        per_page
      else
        25
      end
    end
end
