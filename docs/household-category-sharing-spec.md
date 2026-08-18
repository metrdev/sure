# Household Category Sharing

Status: agreed product specification, 2026-08-18.

## Objective

Members of one household can coordinate selected spending and budgets without granting access to one another's accounts. The product must support a shared household view and an independent personal view in the same Sure family.

A household may have multiple active users. Each user owns their own accounts. Existing explicit account-sharing behavior remains available but is independent of category sharing.

## Non-goals

- Sharing account balances, account names, account identifiers, or bank-provider metadata through a category.
- Debt settlement or calculating who owes whom.
- Approval of individual shared transactions.
- Per-transaction opt-out from a shared category.
- A transaction edit history in the first release.

## Roles

- A household administrator manages shared and aligned category definitions, their modes, hierarchy, and sharing start dates.
- Active administrators and members may edit a shared-category budget limit.
- A member manages their own private categories and personal budgets.
- A member may read, but may not edit, another member's transaction exposed only through category sharing.
- Guest access remains read-only and does not grant household-budget editing.

## Category modes

| Mode | Definition visibility | Transaction visibility | Budget ownership |
| --- | --- | --- | --- |
| Shared | All household members | Eligible operations from all members | One household limit |
| Aligned | All household members | Owner only | One personal limit per member |
| Private | Owner only | Owner only | Owner only |

An administrator-created category defaults to aligned. A non-administrator-created category is private and owned by its creator. An administrator may also create a private category for themselves.

A parent category supplies the default mode to its descendants. A subcategory may explicitly override that mode. A private override has a specific owner.

Shared and aligned category names are unique within the same household parent. Private names are unique within the same owner and parent. A member may not have two visible categories with the same name under the same parent: the product must offer rename or merge instead of creating an ambiguous duplicate.

## Shared transaction eligibility

A transaction is shared with another member when all of the following are true:

1. Both users are active members of the same household.
2. The transaction's effective category mode is shared.
3. The transaction date is on or after the category's effective sharing start date.
4. The transaction date is on or after the viewer's household-sharing access date.

There is no individual exception. Categorizing or recategorizing an operation into a shared category publishes it automatically when it satisfies the dates above. Moving it to an aligned or private category revokes category-derived access immediately.

The owning user retains normal control over the transaction. Another member receives read-only access unless an independent account share grants broader existing permissions.

## Shared transaction contents

The shared transaction view contains the normal transaction card: date, signed amount, currency, name, classification, category, merchant, notes, tags, attachments, and relevant non-account timestamps.

The view must omit or redact:

- account ID, name, type, balance, institution, and provider;
- import source and external identifiers when they can identify an account or provider connection;
- transfer counterpart account data;
- URLs or actions that resolve the private account;
- parent split totals or private split children.

User-authored notes and attachments are shared as part of the full card. The category editor must warn that these fields can contain sensitive information.

For a split transaction, each child is evaluated independently. A shared child is visible and contributes only its own signed amount. A viewer must not be able to infer the private parent total or inspect private siblings.

## Household and personal budgets

The budget experience has two independent sections:

### Household

- Contains only shared categories.
- Has one limit per category and period.
- Counts eligible signed transactions from every household member against that limit.
- Shows each member's contribution and the combined actual.

Example: the shared Groceries limit is 30,000. One member spends 10,000 and another spends 8,000. The household actual is 18,000 and the remaining amount is 12,000.

### My budget

- Contains the current user's aligned and private categories.
- Uses only that user's transactions and personal limits.
- Is not readable by other household members.
- Is not added to the household total.

Budget periods use the household's existing Sure month configuration: either a calendar month or the configured common month-start day.

Every operation in a category contributes using its stored sign. The feature does not introduce a separate expense/refund classification rule.

## Mode transitions

Every transition is a preview-and-confirm operation. The preview shows affected categories, transaction counts, disclosure dates, and budget consequences.

### Aligned to shared

- The administrator chooses a concrete sharing start date.
- The administrator explicitly enters the new household limit.
- Existing personal limits are archived and are not summed automatically.

### Shared to aligned

- Category-derived access to other members' operations is revoked immediately.
- The household limit is archived.
- Every member starts with an empty personal limit.

### Household category to private

- For each member with operations in the category, create an owned private category and move that member's operations to it.
- Do not create a private copy for a member without operations.
- Remove the household definition after all operations have been reassigned.
- A former shared limit is archived; new private limits start empty.
- An existing aligned personal limit follows the member's private copy when that copy is created.

## Membership lifecycle

When inviting a new member, the administrator chooses a household-sharing access date. The member may see a shared transaction only from the later of this date and the category's sharing start date.

When a member leaves or is deactivated:

- their access to other members' shared transactions is revoked immediately;
- their own operations disappear from the remaining household analytics;
- their underlying accounts and transactions remain owned by them under the existing membership-removal policy.

## Migration of existing families

- Every existing category becomes aligned.
- No existing transaction becomes shared during migration.
- For every existing budget period, each active user receives a personal budget with the existing family limits copied into it.
- The old household budget no longer contains aligned categories.
- Administrators subsequently classify categories as shared or private and choose sharing start dates explicitly.

This migration favors non-disclosure over preserving the current family-wide budget view.

## Enforcement boundary

The same server-side visibility decision must govern:

- web transaction lists and details;
- budgets, reports, search, and aggregates;
- API and mobile consumers;
- MCP tools;
- exports and attachments;
- background jobs, cached projections, and notifications.

An interface-only filter is not an acceptable privacy boundary.

## Acceptance scenarios

1. Two members have private accounts. Both categorize purchases as shared Groceries. Both can open the shared transaction cards without seeing either account, and the two signed amounts reduce one household limit.
2. Car is private to one member. It is absent from the other member's category picker, budget, search, reports, API, MCP results, and exports.
3. Dining is aligned. Both members see the same category definition, but neither can see the other's operations or budget limit.
4. A split purchase has one shared child and one private child. The other member sees only the shared child amount and cannot derive the parent total through the application.
5. Recategorizing a transaction into a shared category publishes it when its date is eligible; recategorizing it out revokes access.
6. A direct request for a private account or non-shared transaction returns not found to another member.
7. A category-only API response never serializes private account or transfer-counterpart account data.
8. A new member cannot see shared transactions earlier than their configured access date.
9. Removing a member invalidates their category-derived access and removes their contribution from household actuals.
