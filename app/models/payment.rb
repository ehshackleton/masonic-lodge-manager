class Payment < ApplicationRecord
  belongs_to :brother
  belongs_to :received_by_user, class_name: "User", optional: true
  has_many :payment_allocations, dependent: :destroy
  has_many :charges, through: :payment_allocations

  validates :paid_on, :amount, :currency, presence: true
  validates :amount, numericality: { greater_than: 0 }
end
