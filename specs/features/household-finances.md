---
status: active
owner: household-finances
depends_on:
  - ../product.md
  - ../glossary.md
  - ../shared/category-visibility-and-permissions.md
  - ../shared/budget-ownership.md
  - ../shared/compatibility-and-migration.md
---

# Совместные финансы домохозяйства

## Цель

Active members одного Household используют общие определения категорий, отдельные household/personal budgets и явные household transfers без неявного account sharing. Возможность работает согласованно в web, API, reports, exports и MCP-facing representations.

## Управление категориями

### Создание

- `REQ-HH-001`: administrator может создать household category в aligned mode по умолчанию либо явно выбрать shared/private configuration.
- `REQ-HH-002`: обычный member создает root category только как private owner category.
- `RULE-HH-001`: shared creation требует concrete sharing start date.
- `RULE-HH-002`: private category автоматически получает creator как owner, если authorized workflow не задает другого допустимого owner.
- `RULE-HH-003`: child без override наследует parent mode; UI/API возвращают effective sharing information, достаточную для понимания результата.
- `RULE-HH-004`: category picker показывает household definitions плюс private definitions owner и не предлагает private category для чужого account.

### Изменение mode

- `REQ-HH-003`: изменение effective mode выполняется через preview и явное confirmation web workflow.
- `REQ-HH-004`: preview показывает source/target mode, category IDs ветви, transaction count, member count, earliest disclosed date, name conflicts и budget consequences.
- `RULE-HH-005`: administrator required для изменения household sharing mode; owner может редактировать собственную private category в разрешенных пределах.
- `RULE-HH-006`: изменение без effective mode transition сохраняет обычный update path и не требует transition confirmation.
- `RULE-HH-007`: conflict preview не является разрешением конфликта; invalid duplicate name блокирует execute.

### Household → private

- `RULE-HH-008`: переход shared/aligned category в private всегда создает private root copy для administrator, выполняющего переход, и отдельную copy для каждого другого active member, у которого есть операция в исходной ветви.
- `RULE-HH-009`: member без операций не получает пустую private copy, кроме administrator, выполняющего переход.
- `RULE-HH-010`: subcategories копируются под private root и наследуют его configuration.
- `RULE-HH-011`: операции каждого member перемещаются в его соответствующую private copy в одной database transaction.
- `RULE-HH-012`: исходные household categories архивируются после успешного перемещения.
- `RULE-HH-013`: aligned personal limits переносятся на private copies; shared household limit архивируется, а новые private limits начинаются пустыми.

### Остальные переходы

- `RULE-HH-014`: aligned → shared задает explicit start date, архивирует personal lines и создает empty household line.
- `RULE-HH-015`: shared → aligned немедленно прекращает category-derived access, архивирует household line и создает empty personal lines.
- `RULE-HH-016`: private → shared/aligned снимает owner с definition, применяет соответствующую budget policy и требует отсутствия visible name conflict.
- `RULE-HH-017`: transition не удаляет archived limits и не суммирует прежние personal values в новый household value.

## Shared transaction visibility

- `REQ-HH-005`: viewer получает shared-category operation другого active member только при выполнении `RULE-CAT-016`–`RULE-CAT-020`.
- `RULE-HH-018`: effective disclosure date равна более поздней из category sharing start date и viewer member access date.
- `RULE-HH-019`: administrator задает invitation member access date и может впоследствии изменить дату member в household settings.
- `RULE-HH-020`: изменение member access date немедленно меняет category-derived read range, но не account permissions.
- `RULE-HH-021`: owner сохраняет полный upstream control своей операции; viewer с category-only access получает только read capability.
- `RULE-HH-022`: shared split child показывается отдельно; parent total и private siblings не становятся readable через child.

## Представление category-only operation

- `REQ-HH-006`: web/API показывают дату, display amount, currency, name, classification и category для readable operation.
- `RULE-HH-023`: при отсутствии account permission account ID/name/type, source/external ID и transfer account relation не сериализуются.
- `RULE-HH-024`: merchant, notes, tags и attachments shared-category operation остаются содержимым операции, если operation не является family mirror.
- `RULE-HH-025`: link/action, требующий account permission, не отображается и не разрешается сервером.
- `RULE-HH-026`: family mirror дополнительно скрывает original notes, merchant и tags, использует нейтральное transfer name и отражает amount с точки зрения recipient.

## Household и personal budgets

- `REQ-HH-007`: budget page показывает personal budget viewer и отдельный household budget периода.
- `RULE-HH-027`: household section включает только shared categories, один limit на category и combined actual active members.
- `RULE-HH-028`: personal section включает только операции viewer в aligned/private categories и его uncategorized operations.
- `RULE-HH-029`: member contributions household category показываются по owner фактических операций.
- `RULE-HH-030`: shared amount не входит в personal total; aligned/private amount не входит в household total.
- `RULE-HH-031`: guest не изменяет limits; active non-guest member может изменять household shared limit.

## Money transfers category

- `REQ-HH-008`: каждый Household имеет одну localized Money transfers category с `system_key=money_transfers`.
- `RULE-HH-032`: system category всегда root aligned, без owner и sharing start date.
- `RULE-HH-033`: system category нельзя удалить, merge-away, приватизировать, сделать shared или лишить system identity.
- `RULE-HH-034`: household transfer operation обязана использовать system category; другая category вместе с family counterparty невалидна.

## Создание household transfer

- `REQ-HH-009`: owner writable transaction может выбрать другого active member того же Household как family counterparty.
- `RULE-HH-035`: self counterparty, inactive user, user другого household или operation чужого account невалидны.
- `RULE-HH-036`: назначение counterparty очищает прежний rejection timestamp и переводит operation в system category.
- `RULE-HH-037`: до принятия существует одна owner transaction и read-only mirror, вычисляемое для recipient; отдельная mirror row в database не создается.
- `RULE-HH-038`: owner status равен `sent`, recipient status — `pending`; mirror amount имеет противоположное направление.
- `RULE-HH-039`: recipient может отклонить pending mirror; rejection скрывает mirror из readable scope и дает owner status `rejected`, не удаляя owner transaction.

## Принятие и сопоставление

- `REQ-HH-010`: recipient принимает mirror только в собственный writable account.
- `RULE-HH-040`: recipient может выбрать existing own transaction либо создать missing opposite transaction.
- `RULE-HH-041`: созданная/выбранная recipient transaction получает system category и sender как family counterparty.
- `RULE-HH-042`: accepted pair становится Sure Transfer; обе стороны имеют взаимных family counterparties и status `accepted`.
- `RULE-HH-043`: принятие не требует account permission на sender account; разрешение ограничено конкретным pending mirror и own target account.
- `RULE-HH-044`: family transfer сохраняет фактические amount/date обеих банковских сторон и не требует equality или ordinary four-day window.
- `RULE-HH-045`: обе стороны accepted family transfer используют transaction kind `standard`, чтобы участвовать в обычной аналитике как реальные поступление/расход.
- `RULE-HH-046`: recipient может подтвердить pending matched transfer status-only action без доступа к sender account; остальные transfer edits требуют обычных permissions.

## Обычное автосопоставление переводов

- `RULE-HH-053`: ordinary Sure auto-matcher рассматривает pair только когда обе account sides принадлежат одному non-null owner; совпадение суммы/даты в пределах Household не связывает операции разных members.
- `RULE-HH-054`: связь операций разных members создается только explicit household-transfer workflow по `REQ-HH-009`–`RULE-HH-046`; ordinary auto-match не выводит family counterparty из банковского текста, суммы или даты.

## Unlink

- `REQ-HH-011`: owner может unlink accepted household transfer; recipient работает через разрешенный status/rejection workflow.
- `RULE-HH-047`: unlink уничтожает Transfer relation, но сохраняет обе основные transactions.
- `RULE-HH-048`: обе сохраненные стороны получают `kind=standard`; family counterparties и rejection markers очищаются, если relation была family transfer.
- `RULE-HH-049`: unlink pending mirror до принятия удаляет family relation с owner transaction, но не создает recipient transaction.

## API, reports и export

- `REQ-HH-012`: API categories публикует sharing mode, effective mode/owner/date и system key в пределах visibility caller.
- `REQ-HH-013`: API transaction numeric amount/classification вычисляется с точки зрения viewer; mirror имеет противоположный sign.
- `RULE-HH-050`: API family counterparty содержит только member ID, display name и viewer-specific status.
- `RULE-HH-051`: reports используют `reportable_by(user)` и не включают category-only data, которая не проходит report account/category policy.
- `RULE-HH-052`: user-scoped export следует `RULE-CAT-027`–`RULE-CAT-031` и не становится family-wide dump только из-за admin role.

## Приемка

- `AC-HH-001`: member-created root category private и не видна administrator без independent ownership.
- `AC-HH-002`: administrator создает shared category только с explicit date; eligible operation появляется после обеих access dates.
- `AC-HH-003`: household → private сохраняет private copy administrator даже без его операций, создает copies остальных members только при наличии их operations и перемещает каждую operation к своему owner.
- `AC-HH-004`: household/personal budget sets и actuals не пересекаются.
- `AC-HH-005`: recipient видит pending mirror без sender account/notes/tags/merchant и с противоположным sign.
- `AC-HH-006`: recipient принимает mirror в own existing/new side без sender account permission.
- `AC-HH-007`: accepted family pair сохраняет разные фактические amount/date и имеет взаимных counterparties.
- `AC-HH-008`: reject скрывает mirror, но сохраняет owner operation и показывает owner rejected status.
- `AC-HH-009`: unlink accepted pair сохраняет обе operations и удаляет household relation.
- `AC-HH-010`: API, web, report и export не раскрывают private account metadata через category-derived access.
- `AC-HH-011`: одинаковые по сумме и дате операции счетов разных owners не создают pending ordinary Transfer и не показывают другому member ложное предложение подтверждения.
