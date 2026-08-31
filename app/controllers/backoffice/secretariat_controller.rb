module Backoffice
  class SecretariatController < ApplicationController
    before_action :require_authentication
    before_action :require_current_lodge!
    before_action :authorize_secretariat_access!

    def index
      lodge = current_lodge
      minutes = Minute.for_lodge(lodge)
      correspondences = Correspondence.where(lodge_id: lodge.id)
      tenidas = Tenida.for_lodge(lodge)

      @draft_minutes = minutes.where(status: "draft").count
      @review_minutes = minutes.where(status: "review").count
      @approved_unpublished_minutes = minutes.where(status: "approved").count
      @pending_correspondences = correspondences.where(status: %w[draft review pending]).count
      @upcoming_tenidas_count = tenidas.upcoming.where("held_on <= ?", Date.current + 21.days).count

      @attention_minutes = minutes.needing_attention.ordered.limit(8)
      @attention_correspondences = correspondences.where(status: %w[draft review pending]).order(updated_at: :desc).limit(8)
      @upcoming_tenidas = tenidas.upcoming.where("held_on <= ?", Date.current + 45.days).order(held_on: :asc).limit(8)
      @open_tenidas = tenidas.attention.ordered.limit(8)

      @minutes_recent = minutes.ordered.limit(5)
      @correspondences_recent = correspondences.order(created_at: :desc).limit(5)
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
