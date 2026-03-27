class LedgerEntry < ApplicationRecord
  belongs_to :lodge

  validates :occurred_on, :concept, :reference_type, :reference_id, :debit_account, :credit_account, :amount, :period_year, :period_month, presence: true
  validates :amount, numericality: { greater_than: 0 }
  validates :period_month, inclusion: { in: 1..12 }
end
