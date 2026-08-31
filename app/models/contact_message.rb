class ContactMessage < ApplicationRecord
  STATUSES = %w[new in_progress closed].freeze

  belongs_to :handled_by_user, class_name: "User", optional: true

  before_validation :normalize_fields

  validates :name, :email, :message, presence: true
  validates :email, format: { with: URI::MailTo::EMAIL_REGEXP }
  validates :name, length: { maximum: 120 }
  validates :email, length: { maximum: 180 }
  validates :phone, length: { maximum: 50 }, allow_blank: true
  validates :subject, length: { maximum: 200 }, allow_blank: true
  validates :message, length: { maximum: 5_000 }
  validates :status, inclusion: { in: STATUSES }

  private

  def normalize_fields
    self.name = name.to_s.strip
    self.email = email.to_s.strip.downcase
    self.phone = phone.to_s.strip.presence
    self.subject = subject.to_s.strip.presence
    self.message = message.to_s.strip
    self.status = status.presence || "new"
  end
end
