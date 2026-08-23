---
status: active
owner: budget-ownership
depends_on:
  - ../product.md
  - category-visibility-and-permissions.md
---

# Household и personal budgets

## Ownership и периоды

- `REQ-BUD-001`: для одного household/period существует не более одного household budget с `user_id=NULL`.
- `REQ-BUD-002`: для одного household/member/period существует не более одного personal budget.
- `RULE-BUD-001`: database partial unique indexes отдельно обеспечивают household и personal uniqueness.
- `RULE-BUD-002`: budget user, если указан, должен быть member того же household.
- `RULE-BUD-003`: период использует существующую family month policy: календарный месяц либо custom month start/end.
- `RULE-BUD-004`: `find_or_bootstrap` создает отсутствующий budget в допустимом диапазоне, задает family currency и синхронизирует active lines.

## Category membership

- `REQ-BUD-003`: household budget содержит только shared categories.
- `REQ-BUD-004`: personal budget содержит aligned categories и private categories своего owner.
- `RULE-BUD-005`: синхронизация создает missing active BudgetCategory с zero limit.
- `RULE-BUD-006`: line, категория которой перестала принадлежать budget scope, получает `archived_at` вместо удаления.
- `RULE-BUD-007`: одновременно active может быть только одна line для пары budget/category.
- `RULE-BUD-008`: archived lines не входят в active association, totals или edit UI.

## Фактические суммы

- `REQ-BUD-005`: household actual использует `Transaction.shared_for_household` за период и считает eligible shared operations всех active owners.
- `RULE-BUD-009`: household actual учитывает category sharing start date, но не member-specific viewer date, потому что budget принадлежит household.
- `REQ-BUD-006`: personal actual использует операции счетов owner только в visible aligned/private categories, а также его uncategorized operations.
- `RULE-BUD-010`: shared operations не входят в personal budget; aligned/private operations не входят в household budget.
- `RULE-BUD-011`: excluded upstream transaction kinds и invisible entries продолжают исключаться существующей budget analytics policy.
- `RULE-BUD-012`: category actual равен expense минус refund и не опускается ниже нуля.

## Лимиты и интерфейс

- `REQ-BUD-007`: UI показывает personal budget текущего пользователя и отдельный household budget того же периода.
- `RULE-BUD-013`: household total `budgeted_spending` определяется суммой active allocations; expected/estimated personal income semantics к household budget не применяются.
- `RULE-BUD-014`: guest не может изменять household или personal BudgetCategory через fork controller.
- `RULE-BUD-015`: active non-guest member может изменить household shared-category limit; personal limit изменяет owner своего budget.
- `RULE-BUD-016`: household category detail показывает member contributions по eligible operations.
- `RULE-BUD-024`: summary sections `over budget` и `on track` показывают только category lines с положительным effective limit; root line с zero limit остается в edit UI, но не считается видимой summary line даже при наличии actual spending.
- `RULE-BUD-025`: child line с zero own limit, наследующая положительный parent limit, сохраняет существующую summary visibility как budgeted через effective parent limit.

## Mode transitions

- `RULE-BUD-017`: aligned → shared архивирует personal limits и создает empty household line.
- `RULE-BUD-018`: shared → aligned архивирует household line и создает empty personal lines.
- `RULE-BUD-019`: shared → private архивирует household line и создает empty private lines только для созданных owner copies.
- `RULE-BUD-020`: aligned → private переносит существующий personal limit каждого member с operations на его private copy.
- `RULE-BUD-021`: private → shared архивирует owner personal line и создает empty household line.
- `RULE-BUD-022`: private → aligned сохраняет owner limit и создает empty lines остальных members.
- `RULE-BUD-023`: transition не суммирует personal limits в household limit и не удаляет archived history.

## Приемка

- `AC-BUD-001`: один период дает отдельные household и personal records с разными active category sets.
- `AC-BUD-002`: shared groceries обеих сторон суммируются только в household actual.
- `AC-BUD-003`: aligned groceries другого member не меняют personal actual viewer.
- `AC-BUD-004`: mode transition оставляет прежнюю line archived и новую active line с нормативным initial value.
- `AC-BUD-005`: guest update limit отклоняется.
- `AC-BUD-006`: повторная sync не создает вторую active BudgetCategory.
- `AC-BUD-007`: root category с zero limit и расходами отсутствует в summary sections и их counts, но доступна в budget editor.
