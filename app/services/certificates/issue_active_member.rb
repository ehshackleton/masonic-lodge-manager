# frozen_string_literal: true

module Certificates
  class IssueActiveMember
    def initialize(brother:, issued_by_user:, verification_host:)
      @brother = brother
      @issued_by_user = issued_by_user
      @verification_host = verification_host
    end

    def call
      issue = CertificateIssue.create!(
        lodge: @brother.lodge,
        brother: @brother,
        issued_by_user: @issued_by_user,
        certificate_type: CertificateIssue::CERTIFICATE_TYPES[:active_member]
      )

      verification_url = Rails.application.routes.url_helpers.verify_certificate_url(
        token: issue.token,
        host: @verification_host
      )

      pdf_bytes = ActiveMemberPdf.new(
        brother: @brother,
        issue: issue,
        verification_url: verification_url,
        issued_by: @issued_by_user.full_name
      ).render

      [ issue, pdf_bytes ]
    end
  end
end
