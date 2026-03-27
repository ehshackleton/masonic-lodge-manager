class HospitalFundTransaction < ApplicationRecord
  belongs_to :lodge
  belongs_to :brother, optional: true
  belongs_to :recorded_by_user, class_name: "User", optional: true

  enum :entry_type, {
    income: "income",
    expense: "expense"
  }, prefix: true

  enum :category, {
    contribution: "contribution",
    death_benefit: "death_benefit",
    adjustment: "adjustment"
  }, prefix: true

  validates :occurred_on, :amount, :entry_type, :category, presence: true
  validates :amount, numericality: { greater_than: 0 }
end
