class Charge < ApplicationRecord
  belongs_to :brother
  has_many :payment_allocations, dependent: :destroy
  has_many :payments, through: :payment_allocations

  enum :status, {
    pending: "pending",
    partial: "partial",
    paid: "paid",
    cancelled: "cancelled"
  }, prefix: true

  validates :period_year, :period_month, :amount, presence: true
  validates :amount, numericality: { greater_than_or_equal_to: 0 }

  def paid_amount
    payment_allocations.sum(:applied_amount)
  end

  def pending_amount
    amount - paid_amount
  end
end
