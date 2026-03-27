class AddExtendedProfileFieldsToBrothers < ActiveRecord::Migration[8.1]
  def change
    add_column :brothers, :marital_status, :string
    add_column :brothers, :profession, :string
    add_column :brothers, :employer, :string
    add_column :brothers, :address, :string
    add_column :brothers, :city, :string
    add_column :brothers, :emergency_contact_name, :string
    add_column :brothers, :emergency_contact_phone, :string
    add_column :brothers, :spouse_name, :string
    add_column :brothers, :father_name, :string
    add_column :brothers, :mother_name, :string
    add_column :brothers, :initiation_date, :date
    add_column :brothers, :exaltation_date, :date
    add_column :brothers, :raising_date, :date
    add_column :brothers, :status_since, :date
    add_column :brothers, :deceased_at, :datetime
  end
end
