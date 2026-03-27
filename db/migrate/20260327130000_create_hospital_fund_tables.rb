class CreateHospitalFundTables < ActiveRecord::Migration[8.1]
  def change
    create_table :hospital_fund_settings do |t|
      t.references :lodge, null: false, foreign_key: true
      t.decimal :contribution_amount, precision: 12, scale: 2, null: false, default: 0
      t.decimal :death_benefit_amount, precision: 12, scale: 2, null: false, default: 0
      t.string :currency, null: false, default: "CLP"
      t.boolean :active, null: false, default: true
      t.timestamps
    end

    create_table :hospital_fund_transactions do |t|
      t.references :lodge, null: false, foreign_key: true
      t.references :brother, null: true, foreign_key: true
      t.references :recorded_by_user, null: true, foreign_key: { to_table: :users }
      t.date :occurred_on, null: false
      t.decimal :amount, precision: 12, scale: 2, null: false
      t.string :entry_type, null: false
      t.string :category, null: false
      t.string :reference
      t.text :notes
      t.timestamps
    end

    add_index :hospital_fund_transactions, [:lodge_id, :occurred_on]
    add_index :hospital_fund_transactions, [:lodge_id, :entry_type]
    add_index :hospital_fund_transactions, [:lodge_id, :category]
  end
end
