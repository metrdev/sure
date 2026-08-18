# frozen_string_literal: true

json.partial! "api/v1/transactions/transaction",
              transaction: @transaction,
              account_visible: @accessible_account_ids.nil? || @accessible_account_ids.include?(@transaction.entry.account_id)
