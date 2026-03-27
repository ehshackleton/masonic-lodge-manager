module Backoffice
  class AdministrationController < ApplicationController
    ROLE_MATRIX = {
      "Secretaria" => %w[secretario secretariat_manager minute_editor minute_approver correspondence_editor correspondence_approver],
      "Tesoreria" => %w[tesoreria_manager tesoreria_operator tesoreria_closer tesoreria_exporter],
      "Trabajos" => %w[work_reviewer work_approver work_presenter work_archiver]
    }.freeze
    ROLE_TEMPLATES = {
      "secretario" => {
        name: "Plantilla Secretario",
        role_keys: %w[
          secretario secretariat_manager minute_editor minute_approver correspondence_editor correspondence_approver
          work_reviewer work_approver work_presenter work_archiver
        ]
      },
      "tesorero" => {
        name: "Plantilla Tesorero",
        role_keys: %w[tesoreria_manager tesoreria_operator tesoreria_closer tesoreria_exporter]
      },
      "revisor" => {
        name: "Plantilla Revisor",
        role_keys: %w[work_reviewer]
      }
    }.freeze
    MANAGEABLE_ROLE_KEYS = ROLE_MATRIX.values.flatten.freeze

    before_action :require_authentication
    before_action :authorize_administration!
    before_action :set_target_user, only: %i[update_user_roles apply_role_template]

    def index
      @users = User.includes(:roles).order(:email)
      @manageable_roles = Role.where(key: MANAGEABLE_ROLE_KEYS).order(:name)
      @role_matrix = ROLE_MATRIX.transform_values { |keys| @manageable_roles.select { |role| keys.include?(role.key) } }
      @role_templates = ROLE_TEMPLATES
      @recent_audit_logs = AuditLog.where(action: "administration.user_roles.update")
                                   .includes(:user)
                                   .order(created_at: :desc)
                                   .limit(20)
    end

    def update_user_roles
      selected_role_ids = Array(params[:role_ids]).map(&:to_i)
      allowed_ids = Role.where(key: MANAGEABLE_ROLE_KEYS).pluck(:id)
      final_role_ids = selected_role_ids & allowed_ids

      @target_user.user_roles.where(role_id: allowed_ids).delete_all
      final_role_ids.each do |role_id|
        UserRole.find_or_create_by!(user_id: @target_user.id, role_id: role_id)
      end

      AuditLog.record!(
        user: current_user,
        action: "administration.user_roles.update",
        auditable: @target_user,
        metadata: {
          target_user_email: @target_user.email,
          role_keys: Role.where(id: final_role_ids).pluck(:key)
        },
        ip_address: request.remote_ip,
        user_agent: request.user_agent
      )

      redirect_to "/backoffice/administracion", notice: "Roles actualizados para #{@target_user.email}."
    end

    def apply_role_template
      template_key = params[:template_key].to_s
      template = ROLE_TEMPLATES[template_key]
      unless template
        redirect_to "/backoffice/administracion", alert: "Plantilla de roles no valida."
        return
      end

      allowed_ids = Role.where(key: MANAGEABLE_ROLE_KEYS).pluck(:id)
      template_role_ids = Role.where(key: template[:role_keys]).pluck(:id)

      @target_user.user_roles.where(role_id: allowed_ids).delete_all
      template_role_ids.each do |role_id|
        UserRole.find_or_create_by!(user_id: @target_user.id, role_id: role_id)
      end

      AuditLog.record!(
        user: current_user,
        action: "administration.user_roles.update",
        auditable: @target_user,
        metadata: {
          target_user_email: @target_user.email,
          template_key: template_key,
          template_name: template[:name],
          role_keys: template[:role_keys]
        },
        ip_address: request.remote_ip,
        user_agent: request.user_agent
      )

      redirect_to "/backoffice/administracion", notice: "Plantilla #{template[:name]} aplicada a #{@target_user.email}."
    end

    private

    def set_target_user
      @target_user = User.find(params[:id])
    end

    def authorize_administration!
      return if current_user&.has_role?(:superadmin)

      AuditLog.record!(
        user: current_user,
        action: "permission.denied.administration",
        auditable: current_user,
        metadata: { path: request.path, method: request.request_method },
        ip_address: request.remote_ip,
        user_agent: request.user_agent
      )
      redirect_to "/backoffice", alert: "No tienes permisos para administrar roles."
    end
  end
end
