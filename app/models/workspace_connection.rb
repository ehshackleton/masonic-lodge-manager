# frozen_string_literal: true

class WorkspaceConnection < ApplicationRecord
  include TokenEncryptable

  belongs_to :lodge

  encrypts_token :access_token, :refresh_token

  STATUSES = %w[disconnected connected error].freeze

  validates :provider, presence: true
  validates :status, inclusion: { in: STATUSES }
  validates :lodge_id, uniqueness: { scope: :provider }

  scope :google, -> { where(provider: "google") }

  def connected?
    status == "connected" && refresh_token.present?
  end

  def expired?
    expires_at.present? && expires_at <= Time.current
  end

  def mark_connected!(email:, scopes:)
    update!(
      account_email: email,
      scopes: Array(scopes).join(" "),
      status: "connected",
      last_error: nil
    )
  end

  def mark_error!(message)
    update!(status: "error", last_error: message.to_s.truncate(2000))
  end

  def disconnect!
    update!(
      access_token: nil,
      refresh_token: nil,
      expires_at: nil,
      account_email: nil,
      status: "disconnected",
      last_error: nil
    )
  end
end
