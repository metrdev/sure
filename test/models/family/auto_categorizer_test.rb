require "test_helper"

class Family::AutoCategorizerTest < ActiveSupport::TestCase
  include EntriesTestHelper, ProviderTestHelper

  setup do
    @family = families(:dylan_family)
    @account = @family.accounts.create!(name: "Rule test", balance: 100, currency: "USD", accountable: Depository.new)
    @llm_provider = mock
    Provider::Registry.stubs(:get_provider).with(:openai).returns(@llm_provider)
  end

  test "auto-categorizes transactions" do
    txn1 = create_transaction(account: @account, name: "McDonalds").transaction
    txn2 = create_transaction(account: @account, name: "Amazon purchase").transaction
    txn3 = create_transaction(account: @account, name: "Netflix subscription").transaction

    test_category = @family.categories.create!(name: "Test category")

    provider_response = provider_success_response([
      AutoCategorization.new(transaction_id: txn1.id, category_name: test_category.name),
      AutoCategorization.new(transaction_id: txn2.id, category_name: test_category.name),
      AutoCategorization.new(transaction_id: txn3.id, category_name: nil)
    ])

    @llm_provider.expects(:auto_categorize).returns(provider_response).once

    assert_difference "DataEnrichment.count", 2 do
      Family::AutoCategorizer.new(@family, transaction_ids: [ txn1.id, txn2.id, txn3.id ]).auto_categorize
    end

    assert_equal test_category, txn1.reload.category
    assert_equal test_category, txn2.reload.category
    assert_nil txn3.reload.category

    # After auto-categorization, only successfully categorized transactions are locked
    # txn3 remains enrichable since it didn't get a category (allows retry)
    assert_equal 1, @account.transactions.reload.enrichable(:category_id).count
  end

  test "uses each account owner's visible categories in separate batches" do
    admin = users(:family_admin)
    member = users(:family_member)
    admin_account = @family.accounts.create!(
      owner: admin, name: "Admin AI", balance: 0, currency: "USD", accountable: Depository.new
    )
    member_account = @family.accounts.create!(
      owner: member, name: "Member AI", balance: 0, currency: "USD", accountable: Depository.new
    )
    admin_transaction = create_transaction(account: admin_account, name: "Admin purchase").transaction
    member_transaction = create_transaction(account: member_account, name: "Member purchase").transaction
    admin_private = @family.categories.create!(
      name: "Admin AI private", color: "#123456", lucide_icon: "lock", sharing_mode: "private", owner: admin
    )
    member_private = @family.categories.create!(
      name: "Member AI private", color: "#654321", lucide_icon: "lock", sharing_mode: "private", owner: member
    )
    response = provider_success_response([
      AutoCategorization.new(transaction_id: admin_transaction.id, category_name: admin_private.name),
      AutoCategorization.new(transaction_id: member_transaction.id, category_name: member_private.name)
    ])
    category_names_by_transaction = {}
    @llm_provider.expects(:auto_categorize).twice.with do |transactions:, user_categories:, family:|
      category_names_by_transaction[transactions.first[:id]] = user_categories.pluck(:name)
      family == @family
    end.returns(response)

    Family::AutoCategorizer.new(
      @family,
      transaction_ids: [ admin_transaction.id, member_transaction.id ]
    ).auto_categorize

    assert_equal admin_private, admin_transaction.reload.category
    assert_equal member_private, member_transaction.reload.category
    assert_includes category_names_by_transaction[admin_transaction.id], admin_private.name
    assert_not_includes category_names_by_transaction[admin_transaction.id], member_private.name
    assert_includes category_names_by_transaction[member_transaction.id], member_private.name
    assert_not_includes category_names_by_transaction[member_transaction.id], admin_private.name
  end

  private
    AutoCategorization = Provider::LlmConcept::AutoCategorization
end
