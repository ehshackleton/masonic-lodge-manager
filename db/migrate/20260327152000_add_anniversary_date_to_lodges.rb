class AddAnniversaryDateToLodges < ActiveRecord::Migration[8.1]
  def change
    add_column :lodges, :anniversary_date, :date
  end
end
