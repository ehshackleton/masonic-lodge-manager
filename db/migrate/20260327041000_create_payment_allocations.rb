class CreatePaymentAllocations < ActiveRecord::Migration[8.1]
  def change
    create_table :payment_allocations do |t|
      t.references :payment, null: false, foreign_key: true
      t.references :charge, null: false, foreign_key: true
      t.decimal :applied_amount, precision: 12, scale: 2, null: false
      t.timestamps
    end

    add_index :payment_allocations, %i[payment_id charge_id], unique: true
  end
end
