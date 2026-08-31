class CreateTenidas < ActiveRecord::Migration[8.1]
  def change
    create_table :tenidas do |t|
      t.references :lodge, null: false, foreign_key: true
      t.references :degree, foreign_key: true
      t.references :presiding_brother, foreign_key: { to_table: :brothers }
      t.string :code
      t.date :held_on, null: false
      t.string :tenida_type, null: false, default: "regular"
      t.string :status, null: false, default: "planned"
      t.string :place
      t.time :starts_at
      t.string :presiding_capacity
      t.text :notes
      t.timestamps
    end

    add_index :tenidas, [ :lodge_id, :held_on ]
    add_index :tenidas, [ :lodge_id, :code ], unique: true
    add_index :tenidas, :status

    add_reference :minutes, :tenida, foreign_key: true, null: true
  end
end
