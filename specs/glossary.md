---
status: active
owner: domain-model
depends_on:
  - index.md
---

# Глоссарий household fork

| Термин | Нормативное значение |
| --- | --- |
| Household | Группа active members в одной Sure family, которые используют общие определения и выбранные shared operations, сохраняя владение своими счетами. |
| Member | Пользователь household, владеющий личными счетами и персональным финансовым состоянием. |
| Administrator | Member с правом изменять household category modes, sharing dates и member access dates. |
| Category definition | Именованная category с hierarchy и effective sharing configuration; сама по себе не передает account permission. |
| Shared category | Household category, eligible operations которой читаются active members и входят в один household budget. |
| Aligned category | Общее category definition с личными операциями и отдельным personal limit каждого member. |
| Private category | Category definition и операции, доступные только owner; применима только к счетам owner. |
| Effective mode | Собственный sharing mode категории либо ближайшее унаследованное значение parent. |
| Sharing start date | Первая дата операции, с которой shared category может дать category-derived read access. |
| Member access date | Первая дата операции, которую конкретный member может увидеть через category-derived access. |
| Category-derived access | Read-only доступ к операции другого member через shared category, не сопровождающийся account permission. |
| Household budget | Единственный family-owned budget периода, содержащий только shared categories. |
| Personal budget | Budget периода, принадлежащий конкретному member и содержащий его aligned/private categories. |
| Household transfer | Учетная передача денег между двумя members, а не банковский платеж. |
| Family counterparty | Exact active member, выбранный владельцем операции как другая сторона household transfer. |
| Family mirror | Redacted представление исходной household transaction для получателя до принятия в его счет. |
| Accepted family transfer | Обычный Sure Transfer, обе стороны которого имеют взаимных family counterparties и принадлежат разным members. |
| Money transfers category | Защищенная aligned system category с `system_key=money_transfers`, используемая household transfers. |
| Archived limit | Неактивная BudgetCategory, сохраненная после mode transition и исключенная из текущих расчетов. |

Запрещенные подмены терминов:

- Household в нормативном тексте не называется общим счетом;
- category-derived access не называется account sharing;
- aligned category не называется shared category;
- family mirror не называется копией private account transaction со всеми данными;
- household transfer не называется банковским переводом или погашением долга;
- Rails model `Family` не меняет продуктовый термин Household.
