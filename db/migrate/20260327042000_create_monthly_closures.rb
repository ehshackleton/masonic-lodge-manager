class CreateMonthlyClosures < ActiveRecord::Migration[8.1]
  def change
    create_table :monthly_closures do |t|
      t.references :lodge, null: false, foreign_key: true
      t.integer :period_year, null: false
      t.integer :period_month, null: false
      t.datetime :closed_at, null: false
      t.references :closed_by_user, foreign_key: { to_table: :users }
      t.text :notes
      t.timestamps
    end

    add_index :monthly_closures, %i[lodge_id period_year period_month], unique: true, name: "idx_monthly_closures_period"
  end
end
