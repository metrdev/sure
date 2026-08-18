# Household Category Sharing Implementation Plan

Status: proposed. No implementation has been performed.

## Current constraints

- `Category` belongs to `Family`, and category names are unique per family.
- `Budget` belongs to `Family`, is unique per family period, and synchronizes every family category into `BudgetCategory`.
- Web and API transaction reads are primarily scoped through `Account.accessible_by(user)`.
- The API transaction representation currently always includes account data and transfer counterpart account data.
- The MCP adapter consumes that API and must tolerate a shared transaction whose account block is absent.

These paths are the minimum cross-cutting audit surface; adding a flag to the category view is insufficient.

## Proposed data model

### Categories

Extend category definitions with:

- a mode override: shared, aligned, or private;
- an optional private owner;
- an optional sharing start date.

Root categories have an explicit mode. A child without an override inherits the nearest parent mode and associated owner/start date. Sure currently limits category depth, so effective values can be resolved with the existing parent relationship rather than introducing a general hierarchy engine.

Database constraints and model validations must enforce:

- shared and aligned definitions belong to the household and have no private owner;
- a shared mode has a concrete sharing start date before it can publish operations;
- a private mode has an owner in the same household;
- an aligned or private mode has no active sharing start date;
- shared/aligned names are unique per household parent;
- private names are unique per owner and parent;
- no user resolves two visible same-name categories under the same parent.

Add explicit category scopes for definitions visible to a user and definitions usable in that user's transaction picker. Stop calling `Current.family.categories` directly from user-facing paths unless the path is intentionally administrative.

### Membership sharing boundary

Persist a per-user household-sharing access date. Invitation acceptance records the administrator-selected date. Shared readability uses the later of the membership access date and effective category sharing start date.

Existing users may receive a safe default during migration because no category is made shared automatically.

### Budgets

Introduce household and personal budget ownership while retaining the existing period behavior:

- household budget: family-owned, no user owner, accepts only shared categories;
- personal budget: family plus user owner, accepts only aligned categories visible to that user and their private categories.

Use separate partial unique indexes for one household budget per family/period and one personal budget per family/user/period. Do not rely on nullable-column uniqueness semantics.

Keep `BudgetCategory` as the category-limit record if it can validate the category against the budget owner. Avoid a second parallel budget-line abstraction.

Household actuals read eligible shared transactions across member accounts. Personal actuals read only transactions already available through the user's own or explicitly shared accounts and restrict category modes to aligned/private for the personal budget.

## Access policy

Create one reusable transaction-read scope that returns:

1. transactions available through existing account access; plus
2. read-only transactions granted through a shared category and the two effective dates.

The scope must expose how access was obtained. Presentation code needs to distinguish normal account access from category-only access so it can redact account-related fields.

Write, annotate, delete, split, and transfer permissions continue to use existing account permissions. Category-only access never grants a write capability.

Return not found rather than forbidden when a user attempts to resolve an inaccessible account, category, transaction, attachment, split sibling, or transfer counterpart.

## Serialization and presentation

Add an explicit transaction presenter or policy-aware Jbuilder context rather than sprinkling account checks across templates.

For category-only access:

- omit the API account block;
- omit transfer counterpart account data;
- redact source/external identifiers that reveal provider or account identity;
- suppress account URLs and account-derived actions;
- include only the eligible split child, not its parent total or private siblings.

Update the OpenAPI transaction schema so account data is conditional, and add behavioral Minitest coverage separately from the documentation-only rswag specs required by the repository guidelines.

The MCP client must treat an absent account block as intentional, not malformed, and must never offer write tools for a category-only transaction.

## Category transitions

Implement mode changes as a dedicated preview/execute service with one transaction boundary. The preview contains affected category IDs, member counts, transaction counts, earliest disclosed date, name conflicts, and budget changes.

The executor handles:

- aligned to shared: explicit start date and new household limit; archive personal limits;
- shared to aligned: revoke shared reads, archive household limit, create zero personal limits;
- household to private: create per-member copies only for members with operations, reassign operations, preserve aligned personal limits where applicable, and remove the household definition;
- private to aligned/shared: require administrator action and resolve visible-name conflicts before moving data.

Do not delete historical limit data as part of a transition. Keep enough archived state for audit and a deliberate reversal, but do not expose archived values in active totals.

## Migration

The upgrade migration must be safe by default:

1. Add new columns and indexes without making any transaction shared.
2. Mark every existing category aligned.
3. For every existing family budget period and active user, create a personal budget and copy the family budget and category limits.
4. Remove aligned lines from the household budget or replace the old record with an empty household-period record.
5. Seed safe membership access dates.
6. Validate counts and totals before completing the migration.

Implement and test both a fresh-schema path and an upgrade from the pinned stable v0.7.3 schema. For large tables, separate schema changes from batched data backfill if the test copy shows unacceptable locking.

## Application surfaces to audit

- category settings, pickers, merge, delete, and bootstrap;
- transaction index, details, search, bulk operations, splits, transfers, attachments, and recurring transactions;
- budgets, income statements, reports, dashboard widgets, insights, and caches;
- API v1 categories, transactions, budgets, reports, exports, and attachments;
- mobile consumers of the API;
- MCP reads, previews, and write-tool eligibility;
- family export and account-statement paths;
- notifications and background jobs that embed transaction/category details.

Use the central category and transaction scopes in each path. Do not reproduce visibility SQL independently in controllers.

## Delivery phases

### 1. Domain and schema

- Add category mode/owner/date and membership access date.
- Add household/personal budget ownership.
- Add database constraints, model validations, fixtures, and model tests.
- Implement the existing-family data migration and fresh/upgrade migration tests.

### 2. Read and write policies

- Add visible/usable category scopes.
- Add the policy-aware transaction read scope and category-only access marker.
- Preserve existing account-based write permissions.
- Add adversarial cross-user authorization tests before wiring UI.

### 3. Budgets and reports

- Split household and personal budget queries.
- Calculate household actuals from all eligible shared operations.
- Calculate personal actuals without reading another member's aligned/private data.
- Partition cache keys by household/user/mode/date inputs.

### 4. Web workflows

- Add the two budget sections.
- Add category mode and start-date administration.
- Add transition preview/confirmation.
- Add shared-operation badges and account-redacted transaction details.
- Add invitation sharing-date input.

### 5. API, MCP, export, and mobile safety

- Make API account fields conditional and update OpenAPI documentation.
- Update MCP reads and tool eligibility.
- Apply the same policy to search, export, attachment, and mobile paths.
- Add contract and leakage tests for every consumer.

### 6. End-to-end validation

- Run focused model/controller/system tests, then the full Rails suite and linters.
- Run MCP unit and live-fixture tests against the forked Sure build.
- Exercise both a fresh database and an upgrade fixture based on the pinned v0.7.3 schema.
- Run the two-user privacy scenarios through web, API, and MCP test clients.
- Verify that shared operations appear while accounts remain undiscoverable.

## Security test matrix

At minimum, test both users against each category mode and surface:

- list and direct-ID reads;
- search by merchant, note, tag, amount, and date;
- attachments and split/transfer relations;
- reports, budget actuals, exports, API, and MCP;
- category changes before and after sharing dates;
- invite, deactivate, leave, and rejoin flows;
- caches generated before a permission or mode change.

Every negative case must prove absence of both the record and account-derived metadata.

## Definition of done

- Product scenarios in `docs/household-category-sharing-spec.md` pass as automated tests.
- No category-only path exposes an account identifier or account-derived relation.
- Existing explicit account sharing continues to behave as before.
- Fresh and v0.7.3 upgrade paths pass.
- Two-user web, API, MCP, export, and budget smoke tests pass.
