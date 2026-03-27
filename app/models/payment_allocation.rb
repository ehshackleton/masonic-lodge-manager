class PaymentAllocation < ApplicationRecord
  belongs_to :payment
  belongs_to :charge

  validates :applied_amount, numericality: { greater_than: 0 }
end
