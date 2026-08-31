# frozen_string_literal: true

module SuperadminAuthorization
  extend ActiveSupport::Concern

  private

  def require_superadmin!
    return if current_user&.has_role?(:superadmin)

    AuditLog.record!(
      user: current_user,
      action: "permission.denied.administration",
      auditable: current_user,
      metadata: { path: request.path, method: request.request_method },
      ip_address: request.remote_ip,
      user_agent: request.user_agent
    )
    redirect_to "/backoffice", alert: "No tienes permisos de administracion."
  end
end
