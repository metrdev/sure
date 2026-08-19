# frozen_string_literal: true

json.transactions @transactions do |transaction|
  json.partial! "transaction",
                transaction: transaction,
                viewer: @transaction_viewer,
                account_visible: @accessible_account_ids.include?(transaction.entry.account_id)
end

json.pagination do
  json.page @pagy.page
  json.per_page @per_page
  json.total_count @pagy.count
  json.total_pages @pagy.pages
end
