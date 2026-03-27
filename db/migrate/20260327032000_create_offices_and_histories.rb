class CreateOfficesAndHistories < ActiveRecord::Migration[8.1]
  def change
    create_table :offices do |t|
      t.string :key, null: false
      t.string :name, null: false
      t.string :description
      t.timestamps
    end
    add_index :offices, :key, unique: true

    create_table :brother_degree_histories do |t|
      t.references :brother, null: false, foreign_key: true
      t.references :degree, null: false, foreign_key: true
      t.date :ceremony_date
      t.text :notes
      t.timestamps
    end
    add_index :brother_degree_histories, %i[brother_id degree_id ceremony_date], name: "idx_brother_degree_history_search"

    create_table :brother_office_assignments do |t|
      t.references :brother, null: false, foreign_key: true
      t.references :office, null: false, foreign_key: true
      t.date :start_date
      t.date :end_date
      t.text :notes
      t.timestamps
    end
    add_index :brother_office_assignments, %i[brother_id office_id start_date], name: "idx_brother_office_assignment_search"
  end
end
