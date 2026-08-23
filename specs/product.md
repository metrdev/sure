---
status: active
owner: product
depends_on:
  - index.md
---

# Продуктовый контракт household fork

## Назначение

Fork расширяет Sure совместным финансовым контуром домохозяйства: участники согласуют категории, отдельные household/personal budgets и передачи денег друг другу, сохраняя владение собственными счетами. Доступ к общей операции не должен автоматически раскрывать счет другого участника.

## Пользователи и роли

- administrator — active household member, который управляет household category definitions, sharing modes и датами доступа;
- member — active участник, владеющий своими счетами, private categories и personal budget;
- guest — участник с read-only ограничениями upstream Sure; household budget он видит, но не изменяет;
- API/MCP consumer — клиент, работающий от имени конкретного пользователя и получающий те же ограничения видимости.

## Сценарии

### SCN-PROD-001 — общая классификация без общего счета

Administrator задает shared category и дату начала. Подходящие операции active members становятся читаемы другим участникам, но private account data остается скрытым.

### SCN-PROD-002 — согласованные названия, личные данные

Aligned category имеет общее определение, но операции и бюджетные лимиты каждого участника остаются личными.

### SCN-PROD-003 — полностью личная категория

Member создает private category, доступную только ему и применимую только к его собственным счетам.

### SCN-PROD-004 — два бюджета периода

Пользователь видит household budget для shared categories и собственный personal budget для aligned/private categories. Лимиты и фактические суммы не смешиваются.

### SCN-PROD-005 — передача денег участнику

Владелец операции выбирает другого active member. Получатель видит redacted mirror, может отклонить его или принять в собственный счет существующей/новой банковской стороной.

### SCN-PROD-006 — персональный экспорт

Administrator создает export для себя. Export включает его доступные счета и category-derived readable operations, но не раскрывает account identifiers и private structures других участников.

## Требования продукта

- `REQ-PROD-001`: account ownership и category-derived transaction readability должны быть независимыми измерениями.
- `REQ-PROD-002`: категория должна иметь effective mode `shared`, `aligned` или `private`, включая наследование от parent.
- `REQ-PROD-003`: shared readability должна учитывать category start date и viewer access date.
- `REQ-PROD-004`: category-derived access должен быть read-only и не давать update/delete/attachment/account capability.
- `REQ-PROD-005`: household и personal budgets одного периода должны храниться и рассчитываться отдельно.
- `REQ-PROD-006`: household transfer должен отражать направление для каждого участника без раскрытия private account отправителя.
- `REQ-PROD-007`: mode transition должен показывать последствия до применения и согласованно перемещать/архивировать category/budget state.
- `REQ-PROD-008`: upgrade с pinned v0.7.3 state не должен автоматически сделать существующую транзакцию shared.

## Граница fork delta

Fork нормативно владеет:

- category sharing mode, owner, sharing start date, system key и archive semantics;
- member shared-transactions visibility date;
- household/personal budget ownership и active budget-category membership;
- объединенной transaction read scope и redacted presentation;
- household transfer mirror, acceptance, rejection и unlink semantics;
- user-scoped family export;
- upgrade migration этих данных.

Fork не переопределяет неизмененные upstream contracts счетов, provider sync, обычных переводов, merchants, tags, securities и authentication, кроме мест, где они явно пересекаются с household visibility.

## Нецели

- общий доступ к balances, account names, provider metadata или account identifiers через категорию;
- расчет долгов и взаиморасчетов участников;
- инициирование банковского платежа;
- автоматическое распознавание участника по банковскому тексту;
- per-transaction исключение из shared category;
- сохранение нереализованного roadmap как active behavior.

## Приемка

- `AC-PROD-001`: участник видит eligible shared operation, но не получает account block при отсутствии account permission.
- `AC-PROD-002`: aligned/private operation другого участника не появляется в list, direct read, report или export.
- `AC-PROD-003`: household budget считает shared operations active members, personal budget — только личные aligned/private operations.
- `AC-PROD-004`: recipient mirror показывает правильное направление и может быть принят без доступа к sender account.
- `AC-PROD-005`: existing categories после upgrade aligned, а existing transactions не публикуются как shared.
