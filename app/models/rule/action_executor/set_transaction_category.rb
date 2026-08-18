class Rule::ActionExecutor::SetTransactionCategory < Rule::ActionExecutor
  def type
    "select"
  end

  def options
    scope = Current.user ? family.categories.visible_to(Current.user) : family.categories
    scope.alphabetically.pluck(:name, :id)
  end

  def execute(transaction_scope, value: nil, ignore_attribute_locks: false, rule_run: nil)
    category = family.categories.find_by_id(value)
    return 0 unless category

    scope = transaction_scope
    if category.private?
      scope = scope.joins(entry: :account).where(accounts: { owner_id: category.effective_owner_id })
    end

    unless ignore_attribute_locks
      scope = scope.enrichable(:category_id)
    end

    count_modified_resources(scope) do |txn|
      # enrich_attribute returns true if the transaction was actually modified, false otherwise
      txn.enrich_attribute(
        :category_id,
        category.id,
        source: "rule",
        ignore_locks: ignore_attribute_locks
      )
    end
  end
end
