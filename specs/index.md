# Sure household fork — нормативная спецификация

Статус: `Active`

Каталог `specs/` — единственный авторитетный источник требований к поведению, введенному или измененному этим форком Sure. Спецификация не пытается повторить весь upstream Sure: неизмененное upstream-поведение остается внешней базой, а локальные документы владеют только fork delta и зависимыми контрактами.

## Как читать спецификацию

1. Начать с этого файла.
2. Прочитать [product.md](./product.md) и [glossary.md](./glossary.md).
3. Открыть [features/household-finances.md](./features/household-finances.md).
4. Прочитать все документы из его `depends_on`.
5. Для MCP tools и deployment перейти к [`../../specs/index.md`](../../specs/index.md).

Изменение fork behavior требует обновления owning spec до реализации или в том же наборе изменений. Расхождение активной спецификации, кода, миграций, API representations и тестов является дефектом.

## Статусы

- `Active` — реализованное нормативное поведение без блокирующих открытых вопросов.
- `Draft` — обсуждаемое поведение, не являющееся основанием для реализации.
- `Deprecated` — поддерживаемый контракт с нормативной заменой.
- `Retired` — неподдерживаемый контракт; его идентификатор не переиспользуется.

## Стабильные идентификаторы

- `SCN-*` — пользовательский или автоматизированный сценарий.
- `REQ-*` — требование продукта.
- `RULE-*` — детерминированное правило или ограничение.
- `AC-*` — наблюдаемый критерий приемки.

## Карта канонического владения

| Область поведения | Канонический документ |
| --- | --- |
| Назначение fork delta, пользователи и границы | [product.md](./product.md) |
| Household-термины | [glossary.md](./glossary.md) |
| Режимы категорий, видимость и разрешения | [shared/category-visibility-and-permissions.md](./shared/category-visibility-and-permissions.md) |
| Household/personal budgets и лимиты | [shared/budget-ownership.md](./shared/budget-ownership.md) |
| Миграция v0.7.3 data и compatibility boundary | [shared/compatibility-and-migration.md](./shared/compatibility-and-migration.md) |
| Сквозные household-сценарии категорий, бюджетов и переводов | [features/household-finances.md](./features/household-finances.md) |

## Граница с другими документами

- Upstream `README.md`, `docs/**`, API guide и generated OpenAPI объясняют использование или интеграцию, но не переопределяют fork spec.
- Миграции и schema являются реализацией требований compatibility document.
- Тесты доказывают contract, но отсутствие теста не отменяет активное требование.
- MCP contract находится в parent repository и не копируется сюда.
- Исторические plan, ADR и standalone context files удалены; актуальные правила имеют владельца в этой карте.

## Правила изменения

- `RULE-SPEC-001`: одно fork rule имеет одного канонического владельца.
- `RULE-SPEC-002`: dependent spec ссылается на owning ID и не создает вторую норму.
- `RULE-SPEC-003`: изменение mode transition, visibility, budget ownership, family mirror, API redaction или migration semantics требует изменения owning spec.
- `RULE-SPEC-004`: внутренний Rails design может меняться без изменения spec, если observable contract сохраняется.
- `RULE-SPEC-005`: новое fork behavior вне текущей карты сначала получает canonical owner.
- `RULE-SPEC-006`: active spec описывает только реализованное поведение; roadmap хранится вне нормативного каталога и не маскируется под Active.
