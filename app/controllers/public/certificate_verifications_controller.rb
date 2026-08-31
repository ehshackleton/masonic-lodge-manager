# frozen_string_literal: true

module Public
  class CertificateVerificationsController < ApplicationController
    def show
      @issue = CertificateIssue.includes(:brother, :lodge).find_by(token: params[:token].to_s)
      @valid = @issue&.authentic?
    end
  end
end
