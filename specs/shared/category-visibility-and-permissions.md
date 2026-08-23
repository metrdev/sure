---
status: active
owner: category-access
depends_on:
  - ../product.md
  - ../glossary.md
---

# Категории, видимость и разрешения

## Category modes

- `REQ-CAT-001`: effective category mode принимает `shared`, `aligned` или `private`.
- `RULE-CAT-001`: root category хранит explicit mode; root без mode невалиден.
- `RULE-CAT-002`: child с `sharing_mode=NULL` наследует mode, owner и sharing start date от parent.
- `RULE-CAT-003`: child с explicit mode переопределяет parent configuration в пределах собственной ветви.
- `RULE-CAT-004`: parent и child принадлежат одному household; глубина hierarchy остается ограниченной upstream Sure.

| Mode | Category definition | Operations | Budget |
| --- | --- | --- | --- |
| `shared` | видимо household | eligible operations active members | household |
| `aligned` | видимо household | только owner/account permissions | personal каждого member |
| `private` | только owner | только owner/account permissions | personal owner |

## Configuration invariants

- `RULE-CAT-005`: shared category не имеет owner и требует concrete `sharing_started_on`.
- `RULE-CAT-006`: aligned category не имеет owner и sharing start date.
- `RULE-CAT-007`: private category требует owner из того же household и не имеет sharing start date.
- `RULE-CAT-008`: root category по умолчанию aligned, если privileged caller не задает другой mode.
- `RULE-CAT-009`: root category, созданная обычным member через web/API, принудительно становится private и принадлежит creator.
- `RULE-CAT-010`: category usable для account только внутри того же household; private category usable только для account своего owner.
- `RULE-CAT-011`: archived category отсутствует в default scopes и active pickers.

## Имена и системная категория

- `REQ-CAT-002`: пользователь не должен видеть две одноименные category definitions в одной и той же hierarchy position.
- `RULE-CAT-012`: household shared/aligned names уникальны в household scope; private names уникальны для owner.
- `RULE-CAT-013`: mode transition/merge, создающий visible name conflict, отклоняется до перемещения операций.
- `RULE-CAT-014`: `money_transfers` — единственный поддерживаемый system key и уникален в household.
- `RULE-CAT-015`: Money transfers category является root aligned category без owner/start date; ее system identity, mode и удаление защищены от пользовательского изменения.

## Unified transaction read scope

- `REQ-CAT-003`: active user читает объединение трех независимых источников доступа:
  1. операции счетов из existing `Account.accessible_by(user)`;
  2. eligible shared-category operations active members;
  3. неприкрепленные и неотклоненные family mirrors, адресованные этому user.
- `RULE-CAT-016`: inactive user не получает category-derived или mirror access.
- `RULE-CAT-017`: shared-category operation принадлежит account того же household и active owner.
- `RULE-CAT-018`: transaction date должна быть не раньше effective category start date и viewer member access date.
- `RULE-CAT-019`: split parent не входит в category-derived/mirror scope; eligible split child оценивается отдельно.
- `RULE-CAT-020`: recategorization из shared в aligned/private немедленно убирает category-derived access.
- `RULE-CAT-021`: existing account permission сохраняет upstream capability независимо от category mode.

## Read-only capability

- `REQ-CAT-004`: category-derived access дает чтение, но не update, delete, bulk action, transfer mutation или account navigation.
- `RULE-CAT-022`: контроллеры list/direct read/search/report/export используют centralized readable/reportable scope, а не family-wide transaction scope.
- `RULE-CAT-023`: недоступная запись разрешается как not found, без раскрытия факта ее существования.
- `RULE-CAT-024`: category-only API representation возвращает `account: null`, не возвращает `source`/`external_id` и скрывает transfer account block.
- `RULE-CAT-025`: category-only shared operation может сохранять category, merchant, notes, tags и eligible attachments; family mirror дополнительно редактируется по `RULE-HH-026`.
- `RULE-CAT-026`: transfer counterpart account появляется только при independent account permission viewer.

## User-scoped export

- `REQ-CAT-005`: export принадлежит requesting administrator и недоступен другим administrators того же household.
- `RULE-CAT-027`: export включает только accessible accounts и readable transactions requester.
- `RULE-CAT-028`: category-derived transaction экспортируется без account ID/name; attachment metadata не восстанавливает скрытый account ID.
- `RULE-CAT-029`: exported categories ограничены `visible_to(user)`, budgets — household плюс personal requester.
- `RULE-CAT-030`: user-scoped export не включает family documents и rules, потому что они не имеют безопасного owner scope.
- `RULE-CAT-031`: tags и merchants включаются только когда достижимы через экспортируемые операции/recurring data requester.

## Приемка

- `AC-CAT-001`: shared operation после обеих дат доступна другому active member без account block.
- `AC-CAT-002`: та же операция до category или member date отсутствует в list и direct read.
- `AC-CAT-003`: aligned/private operation другого owner не появляется через category-derived scope.
- `AC-CAT-004`: category-only read не позволяет update/delete/attachment mutation.
- `AC-CAT-005`: shared split child не раскрывает parent total или private sibling.
- `AC-CAT-006`: персональный export не содержит private account/category/rule другого member.
