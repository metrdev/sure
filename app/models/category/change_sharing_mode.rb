class Category::ChangeSharingMode
  Preview = Data.define(
    :source_mode,
    :target_mode,
    :category_ids,
    :transaction_count,
    :member_count,
    :earliest_disclosed_on,
    :name_conflicts,
    :budget_changes
  )

  def self.call!(category:, attributes:, owner:)
    new(category, attributes, owner).call!
  end

  def self.preview(category:, attributes:, owner:)
    new(category, attributes, owner).preview
  end

  def initialize(category, attributes, owner)
    @category = category
    @attributes = attributes.to_h.symbolize_keys
    @attributes[:sharing_mode] = nil if @attributes.key?(:sharing_mode) && @attributes[:sharing_mode].blank?
    @owner = owner
    @family = category.family
  end

  def preview
    category_ids = [ category.id, *category.subcategory_ids ]
    transaction_scope = family.transactions
      .joins(entry: :account)
      .where(category_id: category_ids, accounts: { owner_id: family.users.where(active: true).select(:id) })

    Preview.new(
      source_mode: category.effective_sharing_mode,
      target_mode: target_mode,
      category_ids: category_ids,
      transaction_count: transaction_scope.count,
      member_count: transaction_scope.distinct.count("accounts.owner_id"),
      earliest_disclosed_on: target_mode == "shared" ? attributes[:sharing_started_on] : nil,
      name_conflicts: preview_name_conflicts(category_ids, transaction_scope),
      budget_changes: preview_budget_changes
    )
  end

  def call!
    return update_normally! unless privatizing_household_category?

    Category.transaction do
      source_mode = category.effective_sharing_mode
      source_categories = [ category, *category.subcategories ].index_by(&:id)
      members = members_with_transactions(source_categories.keys)
      limits = personal_limits(source_categories.keys) if source_mode == "aligned"

      ensure_names_available!(members, source_categories.values)

      mappings = members.index_with do |member|
        build_private_copy(member, source_categories.values)
      end

      move_transactions!(mappings)
      archived_at = Time.current
      Category.where(id: source_categories.keys).update_all(archived_at: archived_at, updated_at: archived_at)
      sync_budgets!
      restore_aligned_limits!(limits, mappings) if limits

      mappings[owner]&.fetch(category.id, nil)
    end
  end

  private
    attr_reader :category, :attributes, :owner, :family

    def privatizing_household_category?
      attributes[:sharing_mode] == "private" && !category.private?
    end

    def target_mode
      attributes[:sharing_mode].presence || category.parent&.effective_sharing_mode
    end

    def preview_name_conflicts(category_ids, transaction_scope)
      if target_mode == "private"
        member_ids = transaction_scope.distinct.pluck("accounts.owner_id")
        source_names = family.categories.where(id: category_ids).pluck(:name)

        family.categories
          .where(name: source_names, owner_id: member_ids)
          .where.not(id: category_ids)
          .pluck(:name)
          .uniq
      elsif category.private?
        family.categories
          .where(name: [ category.name, *category.subcategories.pluck(:name) ])
          .where.not(id: category_ids)
          .pluck(:name)
          .uniq
      else
        []
      end
    end

    def preview_budget_changes
      case [ category.effective_sharing_mode, target_mode ]
      when [ "aligned", "shared" ]
        [ :archive_personal_limits, :create_empty_household_limit ]
      when [ "shared", "aligned" ]
        [ :archive_household_limit, :create_empty_personal_limits ]
      when [ "shared", "private" ]
        [ :archive_household_limit, :create_empty_private_limits ]
      when [ "aligned", "private" ]
        [ :move_personal_limits ]
      when [ "private", "shared" ]
        [ :archive_personal_limit, :create_empty_household_limit ]
      when [ "private", "aligned" ]
        [ :keep_owner_limit, :create_empty_personal_limits ]
      else
        []
      end
    end

    def update_normally!
      category.assign_attributes(attributes)
      category.owner = category.sharing_mode == "private" ? owner : nil
      category.sharing_started_on = nil unless category.sharing_mode == "shared"
      category.save!
      sync_budgets!
      category
    end

    def members_with_transactions(category_ids)
      owner_ids = family.transactions
        .joins(entry: :account)
        .where(category_id: category_ids)
        .where(accounts: { owner_id: family.users.where(active: true).select(:id) })
        .distinct
        .pluck("accounts.owner_id")

      family.users.where(id: owner_ids).to_a
    end

    def ensure_names_available!(members, source_categories)
      members.each do |member|
        source_categories.each do |source|
          next unless family.categories.private_for(member).where(name: source.name).where.not(id: source.id).exists?

          source.errors.add(:name, "already exists in #{member.display_name}'s private categories")
          raise ActiveRecord::RecordInvalid, source
        end
      end
    end

    def build_private_copy(member, source_categories)
      source_root = source_categories.find { |source| source.id == category.id }
      root_copy = source_root.dup
      root_copy.assign_attributes(attributes.except(:parent_id))
      root_copy.parent = source_root.parent
      root_copy.sharing_mode = "private"
      root_copy.owner = member
      root_copy.sharing_started_on = nil
      root_copy.save!(validate: false)

      mapping = { source_root.id => root_copy }
      source_categories.reject { |source| source.id == source_root.id }.each do |source_child|
        child_copy = source_child.dup
        child_copy.parent = root_copy
        child_copy.sharing_mode = nil
        child_copy.owner = nil
        child_copy.sharing_started_on = nil
        child_copy.save!(validate: false)
        mapping[source_child.id] = child_copy
      end
      mapping
    end

    def move_transactions!(mappings)
      mappings.each do |member, category_mapping|
        category_mapping.each do |source_id, target|
          family.transactions
            .joins(entry: :account)
            .where(category_id: source_id, accounts: { owner_id: member.id })
            .update_all(category_id: target.id)
        end
      end
    end

    def personal_limits(category_ids)
      family.budgets.where.not(user_id: nil).each_with_object({}) do |budget, limits|
        budget.budget_categories.where(category_id: category_ids).each do |budget_category|
          limits[[ budget.user_id, budget.start_date, budget_category.category_id ]] = budget_category.budgeted_spending
        end
      end
    end

    def restore_aligned_limits!(limits, mappings)
      mappings.each do |member, category_mapping|
        family.budgets.where(user: member).find_each do |budget|
          category_mapping.each do |source_id, target|
            amount = limits[[ member.id, budget.start_date, source_id ]]
            next if amount.nil?

            budget.budget_categories.find_by(category: target)&.update!(budgeted_spending: amount)
          end
        end
      end
    end

    def sync_budgets!
      family.budgets.find_each(&:sync_budget_categories)
    end
end
