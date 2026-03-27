class User < ApplicationRecord
  has_secure_password
  has_many :registered_payments, class_name: "Payment", foreign_key: :received_by_user_id, dependent: :nullify
  has_many :monthly_closures, class_name: "MonthlyClosure", foreign_key: :closed_by_user_id, dependent: :nullify

  before_validation :normalize_email

  validates :email, presence: true, uniqueness: true
  validates :password, length: { minimum: 12 }, allow_nil: true

  def locked?
    locked_at.present?
  end

  private

  def normalize_email
    self.email = email.to_s.strip.downcase
  end
end
