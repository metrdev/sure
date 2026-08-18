class Family::AutoCategorizer
  Error = Class.new(StandardError)

  def initialize(family, transaction_ids: [])
    @family = family
    @transaction_ids = transaction_ids
  end

  def auto_categorize
    raise Error, "No LLM provider for auto-categorization" unless llm_provider

    if scope.none?
      Rails.logger.info("No transactions to auto-categorize for family #{family.id}")
      return 0
    else
      Rails.logger.info("Auto-categorizing #{scope.count} transactions for family #{family.id}")
    end

    scope.to_a.group_by { |transaction| transaction.entry.account.owner }.sum do |owner, transactions|
      auto_categorize_for(owner, transactions)
    end
  end

  private
    attr_reader :family, :transaction_ids

    # Honors Setting.llm_provider (issue #2113) — Provider::Anthropic implements
    # auto_categorize (PR #1984), so batch categorization routes to the configured
    # provider, with fallback handled by Provider::Registry.preferred_llm_provider.
    def llm_provider
      Provider::Registry.preferred_llm_provider
    end

    def auto_categorize_for(owner, transactions)
      categories_input = user_categories_input(owner)
      if categories_input.empty?
        Rails.logger.error("Cannot auto-categorize transactions for family #{family.id}: no categories available")
        return 0
      end

      result = llm_provider.auto_categorize(
        transactions: transactions_input(transactions),
        user_categories: categories_input,
        family: family
      )

      unless result.success?
        Rails.logger.error("Failed to auto-categorize transactions for family #{family.id}: #{result.error.message}")
        return 0
      end

      transactions.count do |transaction|
        auto_categorization = result.data.find { |item| item.transaction_id == transaction.id }
        category_id = categories_input.find { |item| item[:name] == auto_categorization&.category_name }&.dig(:id)
        next false unless category_id

        modified = transaction.enrich_attribute(:category_id, category_id, source: "ai")
        transaction.lock_attr!(:category_id)
        modified
      end
    end

    def user_categories_input(owner)
      categories = owner ? family.categories.visible_to(owner) : family.categories.household

      categories.map do |category|
        {
          id: category.id,
          name: category.name,
          is_subcategory: category.subcategory?,
          parent_id: category.parent_id
        }
      end
    end

    def transactions_input(transactions)
      transactions.map do |transaction|
        {
          id: transaction.id,
          amount: transaction.entry.amount.abs,
          classification: transaction.entry.classification,
          description: [ transaction.entry.name, transaction.entry.notes ].compact.reject(&:empty?).join(" "),
          merchant: transaction.merchant&.name
        }
      end
    end

    def scope
      family.transactions.where(id: transaction_ids, category_id: nil)
                         .enrichable(:category_id)
                         .includes(:category, :merchant, entry: :account)
    end
end
