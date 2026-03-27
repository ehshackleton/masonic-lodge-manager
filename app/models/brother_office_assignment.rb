class BrotherOfficeAssignment < ApplicationRecord
  belongs_to :brother
  belongs_to :office

  validates :office_id, presence: true
  validates :start_date, presence: true
end
