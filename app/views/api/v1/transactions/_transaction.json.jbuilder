# frozen_string_literal: true

json.id transaction.id
json.date transaction.entry.date
family_transfer_mirror = transaction.family_transfer_mirror_for?(viewer)
amount_money = transaction.display_amount_money_for(viewer)
classification = amount_money.amount.negative? ? "income" : "expense"

json.amount amount_money.format

# Agent/automation-friendly numeric fields (avoid localized parsing and clarify sign)
# `amount` in v1 is a localized string and may follow an accounting sign convention.
# Expose minor units (cents) as integers to make the API agent-friendly.
# Uses currency.minor_unit_conversion (e.g. 100 for USD/EUR, 1 for JPY, 1000 for KWD).
conversion_factor = amount_money.currency.minor_unit_conversion
amount_cents = (amount_money.amount * conversion_factor).round(0).to_i.abs
json.amount_cents amount_cents
json.signed_amount_cents(classification == "income" ? amount_cents : -amount_cents)

json.currency transaction.entry.currency
json.name transaction.entry.name
json.notes transaction.entry.notes
if account_visible
  json.external_id transaction.entry.external_id
  json.source transaction.entry.source
end
json.classification classification

# Account information
if account_visible
  json.account do
    json.id transaction.entry.account.id
    json.name transaction.entry.account.name
    json.account_type transaction.entry.account.accountable_type.underscore
  end
else
  json.account nil
end

# Category information
if transaction.category.present?
  json.category do
    json.id transaction.category.id
    json.name transaction.category.name
    json.color transaction.category.color
    json.icon transaction.category.lucide_icon
  end
else
  json.category nil
end

# Merchant information
if transaction.merchant.present? && !family_transfer_mirror
  json.merchant do
    json.id transaction.merchant.id
    json.name transaction.merchant.name
  end
else
  json.merchant nil
end

# Tags
json.tags(family_transfer_mirror ? [] : transaction.tags) do |tag|
  json.id tag.id
  json.name tag.name
  json.color tag.color
end

if transaction.family_counterparty_user_id.present?
  counterparty = family_transfer_mirror ? transaction.entry.account.owner : transaction.family_counterparty_user
  json.family_counterparty do
    json.id counterparty.id
    json.name counterparty.display_name
    json.status(family_transfer_mirror ? "pending" : "sent")
  end
else
  json.family_counterparty nil
end

# Transfer information (if this transaction is part of a transfer)
transfer = transaction.transfer
if transfer.present? && account_visible
  json.transfer do
    json.id transfer.id

    # Other transaction in the transfer
    if transfer.inflow_transaction_id == transaction.id
      inflow_transaction = transaction
      other_transaction = transfer.outflow_transaction
    else
      inflow_transaction = transfer.inflow_transaction
      # When rendering the outflow, the inflow is the counterparty transaction.
      other_transaction = inflow_transaction
    end

    json.amount inflow_transaction.entry.amount_money.abs.format
    json.currency inflow_transaction.entry.currency

    if other_transaction.present? && other_transaction.entry.account.permission_for(viewer).present?
      json.other_account do
        json.id other_transaction.entry.account.id
        json.name other_transaction.entry.account.name
        json.account_type other_transaction.entry.account.accountable_type.underscore
      end
    end
  end
else
  json.transfer nil
end

# Additional metadata
json.created_at transaction.created_at.iso8601
json.updated_at transaction.updated_at.iso8601
