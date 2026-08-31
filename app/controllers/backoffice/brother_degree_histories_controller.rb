module Backoffice
  class BrotherDegreeHistoriesController < ApplicationController
    before_action :require_authentication
    before_action :require_current_lodge!
    before_action :authorize_registry_write_access!
    before_action :set_brother

    def create
      history = @brother.brother_degree_histories.new(history_params)

      if history.save
        @brother.update(current_degree_id: history.degree_id) if history.degree_id.present?
        redirect_to backoffice_brother_path(@brother), notice: "Historial de grado agregado."
      else
        redirect_to backoffice_brother_path(@brother), alert: history.errors.full_messages.to_sentence
      end
    end

    def destroy
      history = @brother.brother_degree_histories.find(params[:id])
      history.destroy
      redirect_to backoffice_brother_path(@brother), notice: "Registro de grado eliminado."
    end

    private

    def set_brother
      @brother = Brother.where(lodge_id: current_lodge.id).find(params[:brother_id])
    end

    def history_params
      params.require(:brother_degree_history).permit(:degree_id, :ceremony_date, :notes)
    end

    def authorize_registry_write_access!
      return if current_user&.can_access_module?(:registry) && current_user&.can_manage_registry_action?(:write)

      AuditLog.record!(
        user: current_user,
        action: "permission.denied.registry",
        auditable: current_user,
        metadata: { denied_action: "registry_write", path: request.path, method: request.request_method },
        ip_address: request.remote_ip,
        user_agent: request.user_agent
      )
      redirect_to "/backoffice", alert: "No tienes permisos para modificar el cuadro logial."
    end
  end
end
