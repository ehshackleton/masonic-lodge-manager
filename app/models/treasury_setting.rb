class TreasurySetting < ApplicationRecord
  belongs_to :lodge

  validates :monthly_fee, numericality: { greater_than_or_equal_to: 0 }
  validates :due_day, numericality: { greater_than_or_equal_to: 1, less_than_or_equal_to: 28 }
  validates :currency, presence: true
end
