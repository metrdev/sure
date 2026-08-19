# frozen_string_literal: true

class AddFamilyMoneyTransfers < ActiveRecord::Migration[7.2]
  def up
    add_column :categories, :system_key, :string
    add_index :categories, [ :family_id, :system_key ], unique: true,
              where: "system_key IS NOT NULL",
              name: "index_categories_on_family_and_system_key"

    add_reference :transactions, :family_counterparty_user,
                  type: :uuid, foreign_key: { to_table: :users }, index: true
    add_column :transactions, :family_transfer_rejected_at, :datetime

    execute <<~SQL.squish
      UPDATE categories
      SET system_key = 'money_transfers', sharing_mode = 'aligned', owner_id = NULL,
          parent_id = NULL, sharing_started_on = NULL, archived_at = NULL
      WHERE id IN (
        SELECT DISTINCT ON (family_id) id
        FROM categories
        WHERE name IN ('Денежные переводы', 'Money transfers')
        ORDER BY family_id, created_at, id
      )
    SQL

    execute <<~SQL.squish
      INSERT INTO categories (id, family_id, name, color, lucide_icon, sharing_mode, system_key, created_at, updated_at)
      SELECT gen_random_uuid(), families.id,
             CASE WHEN families.locale = 'ru' THEN 'Денежные переводы' ELSE 'Money transfers' END,
             '#444CE7', 'handshake', 'aligned', 'money_transfers', CURRENT_TIMESTAMP, CURRENT_TIMESTAMP
      FROM families
      WHERE NOT EXISTS (
        SELECT 1 FROM categories
        WHERE categories.family_id = families.id
          AND categories.system_key = 'money_transfers'
      )
    SQL
  end

  def down
    remove_column :transactions, :family_transfer_rejected_at
    remove_reference :transactions, :family_counterparty_user, foreign_key: { to_table: :users }
    remove_index :categories, name: "index_categories_on_family_and_system_key"
    remove_column :categories, :system_key
  end
end
