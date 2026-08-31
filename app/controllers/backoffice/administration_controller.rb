# frozen_string_literal: true

module Backoffice
  class AdministrationController < ApplicationController
    include SuperadminAuthorization

    before_action :require_authentication
    before_action :require_superadmin!

    def index
      @lodge = Lodge.first
      @recent_audit_logs = AuditLog.where(action: %w[
        administration.user.create
        administration.user.update
        administration.user.deactivate
        administration.user.unlock
        administration.user_roles.update
        administration.lodge.update
      ]).includes(:user).order(created_at: :desc).limit(30)
    end

    def update_lodge
      @lodge = Lodge.first
      unless @lodge
        redirect_to backoffice_administration_path, alert: "No existe una logia configurada."
        return
      end

      if @lodge.update(lodge_params)
        AuditLog.record!(
          user: current_user,
          action: "administration.lodge.update",
          auditable: @lodge,
          metadata: {
            name: @lodge.name,
            anniversary_date: @lodge.anniversary_date&.to_s
          },
          ip_address: request.remote_ip,
          user_agent: request.user_agent
        )
        redirect_to backoffice_administration_path, notice: "Configuracion de la logia actualizada."
      else
        redirect_to backoffice_administration_path, alert: @lodge.errors.full_messages.to_sentence
      end
    end

    private

    def lodge_params
      params.require(:lodge).permit(:name, :description, :anniversary_date)
    end
  end
end
