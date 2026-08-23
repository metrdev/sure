require "test_helper"

class TransferMatchesControllerTest < ActionDispatch::IntegrationTest
  include EntriesTestHelper

  setup do
    sign_in @user = users(:family_admin)
  end

  test "matches existing transaction and creates transfer" do
    inflow_transaction = create_transaction(amount: 100, account: accounts(:depository))
    outflow_transaction = create_transaction(amount: -100, account: accounts(:investment))

    assert_difference "Transfer.count", 1 do
      post transaction_transfer_match_path(inflow_transaction), params: {
        transfer_match: {
          method: "existing",
          matched_entry_id: outflow_transaction.id
        }
      }
    end

    assert_redirected_to transactions_url
    assert_equal "Transfer created", flash[:notice]
  end

  test "creates transfer for target account" do
    inflow_transaction = create_transaction(amount: 100, account: accounts(:depository))

    assert_difference [ "Transfer.count", "Entry.count", "Transaction.count" ], 1 do
      post transaction_transfer_match_path(inflow_transaction), params: {
        transfer_match: {
          method: "new",
          target_account_id: accounts(:investment).id
        }
      }
    end

    assert_redirected_to transactions_url
    assert_equal "Transfer created", flash[:notice]
  end

  test "new transfer entry is protected from provider sync" do
    outflow_entry = create_transaction(amount: 100, account: accounts(:depository))

    post transaction_transfer_match_path(outflow_entry), params: {
      transfer_match: {
        method: "new",
        target_account_id: accounts(:investment).id
      }
    }

    transfer = Transfer.order(created_at: :desc).first
    new_entry = transfer.inflow_transaction.entry

    assert new_entry.user_modified?, "New transfer entry should be marked as user_modified to protect from provider sync"
  end

  test "assigns investment_contribution kind and category for investment destination" do
    # Outflow from depository (positive amount), target is investment
    outflow_entry = create_transaction(amount: 100, account: accounts(:depository))

    post transaction_transfer_match_path(outflow_entry), params: {
      transfer_match: {
        method: "new",
        target_account_id: accounts(:investment).id
      }
    }

    outflow_entry.reload
    outflow_txn = outflow_entry.entryable

    assert_equal "investment_contribution", outflow_txn.kind

    category = @user.family.investment_contributions_category
    assert_equal category, outflow_txn.category
  end

  test "recipient accepts a private family transfer into an owned account" do
    sender = users(:family_admin)
    recipient = users(:family_member)
    family = sender.family
    sender_account = family.accounts.create!(owner: sender, name: "Hidden sender account", balance: 0, currency: family.currency, accountable: Depository.new)
    recipient_account = family.accounts.create!(owner: recipient, name: "Recipient card", balance: 0, currency: family.currency, accountable: Depository.new)
    sender_account.account_shares.destroy_all
    recipient_account.account_shares.destroy_all
    sender_entry = create_transaction(account: sender_account, amount: 30_000, name: "Family cash")
    sender_entry.transaction.update!(category: family.money_transfers_category, family_counterparty_user: recipient)
    sign_in recipient

    get new_transaction_transfer_match_path(sender_entry.transaction), headers: { "Turbo-Frame" => "drawer" }

    assert_response :success
    assert_select "turbo-frame#drawer"
    assert_select "body", text: /Transfer from/
    assert_select "body", text: /Hidden sender account/, count: 0

    assert_difference [ "Transfer.count", "Entry.count", "Transaction.count" ], 1 do
      post transaction_transfer_match_path(sender_entry.transaction), params: {
        transfer_match: { method: "new", target_account_id: recipient_account.id }
      }
    end

    transfer = sender_entry.transaction.reload.transfer
    recipient_transaction = transfer.inflow_transaction
    assert transfer.family_transfer?
    assert_equal recipient_account, recipient_transaction.entry.account
    assert_equal(-30_000, recipient_transaction.entry.amount)
    assert_equal "standard", recipient_transaction.kind
    assert_equal family.money_transfers_category, recipient_transaction.category
    assert_equal sender, recipient_transaction.family_counterparty_user
    assert_not_includes Transaction.readable_by(recipient), sender_entry.transaction
    assert_includes Transaction.readable_by(recipient), recipient_transaction
    sign_in sender
    assert_not_includes Transaction.readable_by(sender), recipient_transaction
    get transfer_path(transfer)
    assert_response :not_found
    sign_in recipient

    assert_difference "Transfer.count", -1 do
      patch unlink_family_transfer_transaction_path(recipient_transaction)
    end
    assert_nil sender_entry.transaction.reload.family_counterparty_user
    assert_nil recipient_transaction.reload.family_counterparty_user
  end

  test "recipient can match a family transfer to an existing owned transaction" do
    sender = users(:family_admin)
    recipient = users(:family_member)
    family = sender.family
    sender_account = family.accounts.create!(owner: sender, name: "Existing match sender", balance: 0, currency: family.currency, accountable: Depository.new)
    recipient_account = family.accounts.create!(owner: recipient, name: "Existing match recipient", balance: 0, currency: family.currency, accountable: Depository.new)
    sender_account.account_shares.destroy_all
    recipient_account.account_shares.destroy_all
    sender_entry = create_transaction(account: sender_account, amount: 12_345, name: "Family transfer to match")
    sender_entry.transaction.update!(category: family.money_transfers_category, family_counterparty_user: recipient)
    recipient_entry = create_transaction(account: recipient_account, amount: -12_345, name: "Imported family income")
    sign_in recipient

    get new_transaction_transfer_match_path(sender_entry.transaction), headers: { "Turbo-Frame" => "drawer" }

    assert_response :success
    assert_select "select[name='transfer_match[matched_entry_id]'] option[value='#{recipient_entry.id}']", count: 1
  end
end
