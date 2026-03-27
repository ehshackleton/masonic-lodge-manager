class CreateLedgerEntries < ActiveRecord::Migration[8.1]
  def change
    create_table :ledger_entries do |t|
      t.references :lodge, null: false, foreign_key: true
      t.date :occurred_on, null: false
      t.string :concept, null: false
      t.string :reference_type, null: false
      t.bigint :reference_id, null: false
      t.string :debit_account, null: false
      t.string :credit_account, null: false
      t.decimal :amount, precision: 12, scale: 2, null: false
      t.integer :period_year, null: false
      t.integer :period_month, null: false
      t.text :notes
      t.timestamps
    end

    add_index :ledger_entries, %i[reference_type reference_id], name: "idx_ledger_entries_reference"
    add_index :ledger_entries, %i[lodge_id period_year period_month], name: "idx_ledger_entries_period"
  end
end
