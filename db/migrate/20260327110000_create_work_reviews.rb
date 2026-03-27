class CreateWorkReviews < ActiveRecord::Migration[8.1]
  def change
    create_table :work_reviews do |t|
      t.references :masonic_work, null: false, foreign_key: true
      t.references :reviewer_user, null: false, foreign_key: { to_table: :users }
      t.date :reviewed_on, null: false
      t.string :status, null: false, default: "commented"
      t.text :comments
      t.timestamps
    end
  end
end
