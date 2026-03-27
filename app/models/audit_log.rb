class AuditLog < ApplicationRecord
  belongs_to :user, optional: true

  validates :action, :auditable_type, :auditable_id, presence: true

  def self.record!(user:, action:, auditable:, metadata: {}, ip_address: nil, user_agent: nil)
    create!(
      user: user,
      action: action,
      auditable_type: auditable.class.name,
      auditable_id: auditable.id,
      metadata: metadata,
      ip_address: ip_address,
      user_agent: user_agent
    )
  end
end
