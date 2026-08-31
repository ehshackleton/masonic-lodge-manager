# frozen_string_literal: true

class CertificateIssue < ApplicationRecord
  CERTIFICATE_TYPES = {
    active_member: "active_member"
  }.freeze

  belongs_to :lodge
  belongs_to :brother
  belongs_to :issued_by_user, class_name: "User"

  validates :certificate_type, :folio, :token, :verification_code, :digest, :issued_on, presence: true
  validates :folio, :token, :verification_code, uniqueness: true

  scope :active, -> { where(revoked_at: nil) }
  scope :ordered, -> { order(issued_on: :desc, created_at: :desc) }

  before_validation :assign_issue_credentials, on: :create

  def revoked?
    revoked_at.present?
  end

  def authentic?
    !revoked? && digest == compute_digest
  end

  def digital_seal
    digest.to_s.first(16).upcase.scan(/.{4}/).join("-")
  end

  def recompute_digest!
    update!(digest: compute_digest)
  end

  private

  def assign_issue_credentials
    self.issued_on ||= Date.current
    self.token ||= SecureRandom.urlsafe_base64(18)
    self.verification_code ||= "AM#{SecureRandom.alphanumeric(8).upcase}"
    self.folio ||= next_folio
    self.digest = compute_digest
  end

  def next_folio
    year = issued_on.year
    sequence = CertificateIssue.where(lodge_id: lodge_id, issued_on: issued_on.all_year).count + 1
    "CERT-#{year}-#{sequence.to_s.rjust(5, '0')}"
  end

  def compute_digest
    payload = [ token, brother_id, lodge_id, folio, issued_on.to_s, certificate_type ].join("|")
    OpenSSL::HMAC.hexdigest("SHA256", Rails.application.secret_key_base, payload)
  end
end
