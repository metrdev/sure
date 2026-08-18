# frozen_string_literal: true

class AddHouseholdCategorySharing < ActiveRecord::Migration[7.2]
  def up
    add_column :categories, :sharing_mode, :string
    add_reference :categories, :owner, type: :uuid, foreign_key: { to_table: :users }, index: true
    add_column :categories, :sharing_started_on, :date
    add_column :categories, :archived_at, :datetime

    add_column :users, :shared_transactions_visible_from, :date, default: -> { "CURRENT_DATE" }, null: false
    add_column :invitations, :shared_transactions_visible_from, :date, default: -> { "CURRENT_DATE" }, null: false
    add_reference :family_exports, :requested_by, type: :uuid, foreign_key: { to_table: :users }, index: true

    add_reference :budgets, :user, type: :uuid, foreign_key: true, index: true
    add_column :budget_categories, :archived_at, :datetime
    remove_index :budget_categories, name: "index_budget_categories_on_budget_id_and_category_id"
    add_index :budget_categories, [ :budget_id, :category_id ],
              unique: true,
              where: "archived_at IS NULL",
              name: "index_active_budget_categories_on_budget_and_category"
    remove_index :budgets, name: "index_budgets_on_family_id_and_start_date_and_end_date"

    add_index :budgets, [ :family_id, :start_date, :end_date ],
              unique: true,
              where: "user_id IS NULL",
              name: "index_household_budgets_on_family_and_period"
    add_index :budgets, [ :family_id, :user_id, :start_date, :end_date ],
              unique: true,
              where: "user_id IS NOT NULL",
              name: "index_personal_budgets_on_family_user_and_period"

    add_index :categories, [ :family_id, :name ],
              where: "owner_id IS NULL AND archived_at IS NULL",
              name: "index_household_categories_on_family_and_name"
    add_index :categories, [ :family_id, :owner_id, :name ],
              where: "owner_id IS NOT NULL AND archived_at IS NULL",
              name: "index_private_categories_on_family_owner_and_name"

    add_check_constraint :categories,
                         "sharing_mode IS NULL OR sharing_mode IN ('shared', 'aligned', 'private')",
                         name: "categories_sharing_mode_check"

    execute <<~SQL.squish
      UPDATE categories
      SET sharing_mode = 'aligned'
      WHERE parent_id IS NULL
    SQL

    copy_existing_budgets_to_active_users

    execute <<~SQL.squish
      UPDATE budget_categories
      SET archived_at = CURRENT_TIMESTAMP
      WHERE budget_id IN (SELECT id FROM budgets WHERE user_id IS NULL)
    SQL

    execute <<~SQL.squish
      UPDATE budgets
      SET budgeted_spending = 0, expected_income = 0
      WHERE user_id IS NULL
    SQL
  end

  def down
    execute <<~SQL.squish
      UPDATE budgets household
      SET
        budgeted_spending = personal.budgeted_spending,
        expected_income = personal.expected_income
      FROM (
        SELECT DISTINCT ON (family_id, start_date, end_date)
          family_id, start_date, end_date, budgeted_spending, expected_income
        FROM budgets
        WHERE user_id IS NOT NULL
        ORDER BY family_id, start_date, end_date, created_at, id
      ) personal
      WHERE household.user_id IS NULL
        AND household.family_id = personal.family_id
        AND household.start_date = personal.start_date
        AND household.end_date = personal.end_date
    SQL

    execute <<~SQL.squish
      DELETE FROM budget_categories active_limits
      USING budgets
      WHERE active_limits.budget_id = budgets.id
        AND budgets.user_id IS NULL
        AND active_limits.archived_at IS NULL
    SQL

    execute <<~SQL.squish
      DELETE FROM budget_categories archived_limits
      USING budgets
      WHERE archived_limits.budget_id = budgets.id
        AND budgets.user_id IS NULL
        AND archived_limits.archived_at IS NOT NULL
        AND archived_limits.id NOT IN (
          SELECT DISTINCT ON (budget_id, category_id) id
          FROM budget_categories
          WHERE archived_at IS NOT NULL
          ORDER BY budget_id, category_id, created_at, id
        )
    SQL

    execute <<~SQL.squish
      UPDATE budget_categories
      SET archived_at = NULL
      WHERE budget_id IN (SELECT id FROM budgets WHERE user_id IS NULL)
        AND archived_at IS NOT NULL
    SQL

    execute <<~SQL.squish
      DELETE FROM budget_categories
      WHERE budget_id IN (SELECT id FROM budgets WHERE user_id IS NOT NULL)
    SQL
    execute "DELETE FROM budgets WHERE user_id IS NOT NULL"

    remove_check_constraint :categories, name: "categories_sharing_mode_check"
    remove_index :categories, name: "index_private_categories_on_family_owner_and_name"
    remove_index :categories, name: "index_household_categories_on_family_and_name"
    remove_index :budgets, name: "index_personal_budgets_on_family_user_and_period"
    remove_index :budgets, name: "index_household_budgets_on_family_and_period"
    remove_index :budget_categories, name: "index_active_budget_categories_on_budget_and_category"
    add_index :budget_categories, [ :budget_id, :category_id ],
              unique: true,
              name: "index_budget_categories_on_budget_id_and_category_id"
    remove_column :budget_categories, :archived_at
    add_index :budgets, [ :family_id, :start_date, :end_date ],
              unique: true,
              name: "index_budgets_on_family_id_and_start_date_and_end_date"

    remove_reference :budgets, :user, foreign_key: true
    remove_column :invitations, :shared_transactions_visible_from
    remove_column :users, :shared_transactions_visible_from
    remove_reference :family_exports, :requested_by, foreign_key: { to_table: :users }
    execute <<~SQL.squish
      DELETE FROM budget_categories
      WHERE category_id IN (SELECT id FROM categories WHERE archived_at IS NOT NULL)
    SQL
    execute "DELETE FROM categories WHERE archived_at IS NOT NULL"
    remove_column :categories, :archived_at
    remove_column :categories, :sharing_started_on
    remove_reference :categories, :owner, foreign_key: { to_table: :users }
    remove_column :categories, :sharing_mode
  end

  private

    def copy_existing_budgets_to_active_users
      execute <<~SQL.squish
        INSERT INTO budgets (
          id, family_id, user_id, start_date, end_date,
          budgeted_spending, expected_income, currency, created_at, updated_at
        )
        SELECT
          gen_random_uuid(), budgets.family_id, users.id, budgets.start_date, budgets.end_date,
          budgets.budgeted_spending, budgets.expected_income, budgets.currency,
          CURRENT_TIMESTAMP, CURRENT_TIMESTAMP
        FROM budgets
        INNER JOIN users ON users.family_id = budgets.family_id AND users.active = TRUE
        WHERE budgets.user_id IS NULL
      SQL

      execute <<~SQL.squish
        INSERT INTO budget_categories (
          id, budget_id, category_id, budgeted_spending, currency, created_at, updated_at
        )
        SELECT
          gen_random_uuid(), personal_budgets.id, budget_categories.category_id,
          budget_categories.budgeted_spending, budget_categories.currency,
          CURRENT_TIMESTAMP, CURRENT_TIMESTAMP
        FROM budget_categories
        INNER JOIN budgets household_budgets ON household_budgets.id = budget_categories.budget_id
        INNER JOIN budgets personal_budgets
          ON personal_budgets.family_id = household_budgets.family_id
          AND personal_budgets.start_date = household_budgets.start_date
          AND personal_budgets.end_date = household_budgets.end_date
          AND personal_budgets.user_id IS NOT NULL
        WHERE household_budgets.user_id IS NULL
      SQL
    end
end
