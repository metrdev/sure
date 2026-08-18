---
status: accepted
---

# Separate household and personal category scopes

Sure will model shared and aligned categories as household definitions, private categories as member-owned definitions, household budgets as shared-category budgets, and personal budgets as member-owned aligned/private budgets. Transactions remain owned through their accounts, but a shared category grants a separate read-only capability after the effective category and membership dates. That capability is enforced by server-side query and presentation policies across every consumer, with account data redacted when access exists only because of the category.

## Considered options

- **Reuse account sharing:** rejected because it exposes balances and unrelated transactions, which is the boundary this feature must avoid.
- **Keep one family budget and filter the UI:** rejected because the stored budget remains shared and non-UI consumers can still disclose it.
- **Duplicate every category per member:** rejected because aligned names and hierarchy would drift and require ongoing synchronization.
- **Authorize only in controllers and views:** rejected because API, MCP, exports, reports, attachments, and background projections would develop inconsistent privacy rules.

## Consequences

Budget ownership and transaction readability become separate dimensions. Existing family budgets require a data migration, shared transaction serialization must support account redaction, and all account-based transaction scopes must be audited. In return, explicit account sharing remains unchanged and household coordination no longer requires exposing accounts.
