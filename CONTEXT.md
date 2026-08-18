# Household Finance

This context describes how members of one household coordinate categories, transactions, and budgets without sharing their financial accounts.

## Language

**Household**:
A group of members who share selected financial definitions and activity while retaining ownership of their own accounts.
_Avoid_: Family, group

**Member**:
A person who belongs to a household and owns their personal financial data.
_Avoid_: Account, profile

**Household Administrator**:
A member who controls household-wide category definitions, category modes, and sharing start dates.
_Avoid_: Owner

**Category Mode**:
The rule that determines whether a category definition, its transactions, and its budget are household-wide or personal.
_Avoid_: Permission level, account sharing

**Shared Category**:
A household category whose eligible transactions and single budget limit are shared by all members.
_Avoid_: Joint account category

**Aligned Category**:
A household category with a common name and hierarchy but personal transactions and personal budgets for each member.
_Avoid_: Common category, shared category

**Private Category**:
A category definition, transactions, and budget visible only to its owning member.
_Avoid_: Hidden shared category

**Shared Transaction**:
A transaction made readable to household members because its effective category mode is shared and its date is within the permitted sharing interval.
_Avoid_: Shared account transaction

**Sharing Start Date**:
The earliest transaction date from which a shared category may expose transactions to eligible household members.
_Avoid_: Creation date, publication date

**Household Budget**:
The collection of shared-category limits and actuals for one household budget period.
_Avoid_: Family-wide personal budget

**Personal Budget**:
A member's aligned-category and private-category limits and actuals for one budget period.
_Avoid_: Household budget
