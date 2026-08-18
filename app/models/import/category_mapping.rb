class Import::CategoryMapping < Import::Mapping
  class << self
    def mappables_by_key(import)
      unique_values = import.rows.map(&:category).uniq

      # For hierarchical QIF keys like "Home:Home Improvement", look up the child
      # name ("Home Improvement"). Prefer the account owner's private category
      # when its name also exists in the household namespace.
      lookup_names = unique_values.map { |v| leaf_category_name(v) }
      categories = available_categories(import).where(name: lookup_names).to_a
        .group_by(&:name)
        .transform_values { |matches| preferred_category(matches, import) }

      unique_values.index_with { |value| categories[leaf_category_name(value)] }
    end

    private

      # Returns the leaf (child) name for a potentially hierarchical key.
      # "Home:Home Improvement" → "Home Improvement"
      # "Fees & Charges"        → "Fees & Charges"
      def leaf_category_name(key)
        return "" if key.blank?

        parts = key.to_s.split(":", 2)
        parts.length == 2 ? parts[1].strip : key
      end

      def available_categories(import)
        owner = category_owner(import)

        owner ? import.family.categories.visible_to(owner) : import.family.categories.household
      end

      def preferred_category(matches, import)
        owner = category_owner(import)
        matches.find { |category| category.private? && category.effective_owner_id == owner&.id } ||
          matches.find { |category| !category.private? }
      end

      def category_owner(import)
        import.account&.owner || (Current.user if Current.user&.family_id == import.family_id)
      end
  end

  def selectable_values
    family_categories = self.class.send(:available_categories, import)
                            .alphabetically
                            .map { |category| [ category.name, category.id ] }

    unless key.blank?
      family_categories.unshift [ "Add as new category", CREATE_NEW_KEY ]
    end

    family_categories
  end

  def requires_selection?
    false
  end

  def values_count
    import.rows.where(category: key).count
  end

  def mappable_class
    Category
  end

  def create_mappable!
    return unless creatable?

    parts = key.split(":", 2)

    if parts.length == 2
      parent_name = parts[0].strip
      child_name  = parts[1].strip

      if category_owner && !category_owner.admin?
        self.mappable = available_categories.find_by(name: child_name) || create_private_category!(child_name)
        save!
        return
      end

      # Ensure the parent category exists before creating the child.
      parent = available_categories.find_or_create_by!(name: parent_name) do |cat|
        apply_ownership(cat)
        cat.color = Category::COLORS.sample
        cat.lucide_icon = Category.suggested_icon(parent_name)
      end

      self.mappable = available_categories.find_or_create_by!(name: child_name) do |cat|
        cat.parent = parent
        cat.color = parent.color
        cat.lucide_icon = Category.suggested_icon(child_name)
      end
    else
      self.mappable = available_categories.find_or_create_by!(name: key) do |cat|
        apply_ownership(cat)
        cat.color = Category::COLORS.sample
        cat.lucide_icon = Category.suggested_icon(key)
      end
    end

    save!
  end

  private
    def available_categories
      self.class.send(:available_categories, import)
    end

    def apply_ownership(category)
      owner = category_owner
      return unless owner && !owner.admin?

      category.sharing_mode = "private"
      category.owner = owner
    end

    def category_owner
      self.class.send(:category_owner, import)
    end

    def create_private_category!(name)
      import.family.categories.create!(
        name: name,
        color: Category::COLORS.sample,
        lucide_icon: Category.suggested_icon(name),
        sharing_mode: "private",
        owner: category_owner
      )
    end
end
