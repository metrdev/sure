require "test_helper"

class Assistant::Function::GetTransactionsTest < ActiveSupport::TestCase
  test "family transfer mirror is income without sender account details" do
    sender = users(:family_admin)
    recipient = users(:family_member)
    family = sender.family
    account = family.accounts.create!(
      owner: sender,
      name: "Private sender card",
      balance: 0,
      currency: family.currency,
      accountable: Depository.new
    )
    account.account_shares.destroy_all
    entry = account.entries.create!(
      name: "Private bank description",
      date: Date.current,
      amount: 12_000,
      currency: family.currency,
      entryable: Transaction.new(
        category: family.money_transfers_category,
        family_counterparty_user: recipient,
        merchant: family.available_merchants.first,
        tags: family.tags.limit(1)
      )
    )

    result = Assistant::Function::GetTransactions.new(recipient).call("order" => "desc", "page" => 1)
    item = result.fetch(:transactions).find { |transaction| transaction[:name] == entry.transaction.family_transfer_name_for(recipient) }

    assert item
    assert_equal "income", item[:classification]
    assert_nil item[:account]
    assert_nil item[:merchant]
    assert_empty item[:tags]
    assert_not item[:is_transfer]
  end
end
