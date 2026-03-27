class Office < ApplicationRecord
  has_many :brother_office_assignments, dependent: :restrict_with_error
  has_many :brothers, through: :brother_office_assignments

  validates :key, presence: true, uniqueness: true
  validates :name, presence: true
end
