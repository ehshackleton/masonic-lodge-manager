module Backoffice
  class SecretariatController < ApplicationController
    before_action :require_authentication
    before_action :authorize_secretariat_access!

    def index
      @minutes_recent = Minute.order(session_date: :desc).limit(5)
      @correspondences_recent = Correspondence.order(created_at: :desc).limit(5)
      @pending_correspondences = Correspondence.where(status: %w[pending draft]).count
      @draft_minutes = Minute.where(status: "draft").count
    end

    private

    def authorize_secretariat_access!
      return if current_user&.can_access_module?(:secretariat)

      AuditLog.record!(
        user: current_user,
        action: "permission.denied.secretariat.module",
        auditable: current_user,
        metadata: { path: request.path, method: request.request_method },
        ip_address: request.remote_ip,
        user_agent: request.user_agent
      )
      redirect_to "/backoffice", alert: "No tienes permisos para acceder a Secretaria."
    end
  end
end
