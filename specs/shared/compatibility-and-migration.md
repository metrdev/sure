---
status: active
owner: household-migration
depends_on:
  - ../product.md
  - category-visibility-and-permissions.md
  - budget-ownership.md
---

# Совместимость и миграция

## Baseline

Fork household schema накладывается на pinned upstream Sure v0.7.3. Миграции должны поддерживать fresh schema execution и upgrade существующей v0.7.3 базы без автоматической публикации исторических операций.

## Category/budget migration

- `REQ-MIG-001`: migration добавляет category mode, owner, sharing start, archive state и member/invitation access dates.
- `RULE-MIG-001`: все existing root categories получают `sharing_mode=aligned`; child inheritance сохраняется через `NULL` mode.
- `RULE-MIG-002`: migration не назначает existing category shared и не создает category-derived read access к историческим операциям.
- `RULE-MIG-003`: access date существующих users/invitations получает безопасное non-null значение текущей даты migration.
- `REQ-MIG-002`: каждый existing budget копируется в personal budget каждого active member того же household.
- `RULE-MIG-004`: personal copy сохраняет period, currency, aggregate fields и category limits existing budget.
- `RULE-MIG-005`: прежние household lines архивируются, а household aggregate spending/income сбрасываются в zero.
- `RULE-MIG-006`: household/personal uniqueness обеспечивается разными partial indexes; active BudgetCategory uniqueness учитывает `archived_at IS NULL`.

## Household-transfer migration

- `REQ-MIG-003`: migration добавляет category `system_key`, transaction family counterparty и rejection timestamp.
- `RULE-MIG-007`: для каждого household существует ровно одна root aligned Money transfers category с `system_key=money_transfers`.
- `RULE-MIG-008`: migration сначала переиспользует earliest existing category с локализованным именем Money transfers, если она существует, иначе создает новую.
- `RULE-MIG-009`: system category не имеет owner, parent, sharing start или archive state.
- `RULE-MIG-010`: добавление household-transfer columns само по себе не помечает existing transaction как family transfer.

## Downgrade contract

- `RULE-MIG-011`: down migration household categories восстанавливает один representative personal budget в прежний household shape перед удалением personal records.
- `RULE-MIG-012`: archived category copies/limits, несовместимые с legacy schema, удаляются перед удалением archive columns.
- `RULE-MIG-013`: downgrade является техническим rollback schema, а не гарантией сохранения всех post-upgrade household semantics.

## Compatibility rules

- `REQ-MIG-004`: API account block становится nullable для category-only visibility; clients должны отличать redaction от malformed transaction.
- `REQ-MIG-005`: category API расширяется sharing fields и system key без изменения ID существующих categories.
- `RULE-MIG-014`: user-facing date parsing использует family locale/date policy; persistence хранит date без timezone conversion.
- `RULE-MIG-015`: existing explicit account sharing продолжает давать прежние capabilities и имеет приоритет над category-only redaction.
- `RULE-MIG-016`: fork не перемещает account ownership и не создает account permissions при upgrade.

## Приемка

- `AC-MIG-001`: upgrade populated v0.7.3 family создает personal budget каждого active member с прежними limits.
- `AC-MIG-002`: сразу после upgrade ни одна existing operation не доступна другому member только через category.
- `AC-MIG-003`: повторная Money transfers bootstrap не создает вторую system category.
- `AC-MIG-004`: fresh database применяет обе migrations и удовлетворяет check constraints/indexes.
- `AC-MIG-005`: existing account-shared transaction продолжает возвращать account block authorized viewer.
