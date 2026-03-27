class CreateTreasurySettings < ActiveRecord::Migration[8.1]
  def change
    create_table :treasury_settings, if_not_exists: true do |t|
      t.references :lodge, null: false, foreign_key: true
      t.decimal :monthly_fee, precision: 12, scale: 2, null: false, default: 0
      t.string :currency, null: false, default: "CLP"
      t.integer :due_day, null: false, default: 10
      t.boolean :active, null: false, default: true
      t.timestamps
    end
  end
end
