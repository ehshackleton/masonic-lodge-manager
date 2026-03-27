class MonthlyClosure < ApplicationRecord
  belongs_to :lodge
  belongs_to :closed_by_user, class_name: "User", optional: true

  validates :period_year, :period_month, :closed_at, presence: true
  validates :period_month, inclusion: { in: 1..12 }
end
