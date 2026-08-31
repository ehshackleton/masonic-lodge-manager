# frozen_string_literal: true

module Backoffice
  class AdminUsersController < ApplicationController
    include SuperadminAuthorization

    before_action :require_authentication
    before_action :require_superadmin!
    before_action :set_user, only: %i[edit update destroy unlock apply_role_template]

    def index
      @users = User.includes(:roles).order(:email)
    end

    def new
      @user = User.new(active: true)
      load_role_form_data
    end

    def create
      @user = User.new(user_params)

      if user_params[:password].blank?
        @user.errors.add(:password, "es obligatoria al crear un usuario")
      end

      if @user.errors.empty? && @user.save
        Administration::RoleCatalog.sync_roles!(
          user: @user,
          role_ids: params[:role_ids],
          superadmin: superadmin_checked?
        )
        audit_user_change!("administration.user.create", role_keys: @user.roles.pluck(:key))
        redirect_to backoffice_admin_users_path, notice: "Usuario #{@user.email} creado."
      else
        load_role_form_data
        render :new, status: :unprocessable_entity
      end
    end

    def edit
      load_role_form_data
    end

    def update
      attrs = user_params
      password = attrs.delete(:password)
      password_confirmation = attrs.delete(:password_confirmation)

      if password.present?
        attrs[:password] = password
        attrs[:password_confirmation] = password_confirmation
      end

      if removing_own_superadmin?
        redirect_to edit_backoffice_admin_user_path(@user), alert: "No puede quitarse el rol superadmin a si mismo."
        return
      end

      if @user.update(attrs)
        Administration::RoleCatalog.sync_roles!(
          user: @user,
          role_ids: params[:role_ids],
          superadmin: superadmin_checked?
        )
        audit_user_change!("administration.user.update", role_keys: @user.reload.roles.pluck(:key))
        redirect_to backoffice_admin_users_path, notice: "Usuario #{@user.email} actualizado."
      else
        load_role_form_data
        render :edit, status: :unprocessable_entity
      end
    end

    def destroy
      if @user.id == current_user.id
        redirect_to backoffice_admin_users_path, alert: "No puede desactivar su propia cuenta."
        return
      end

      @user.update!(active: false, locked_at: Time.current)
      audit_user_change!("administration.user.deactivate")
      redirect_to backoffice_admin_users_path, notice: "Usuario #{@user.email} desactivado."
    end

    def unlock
      @user.update!(failed_attempts: 0, locked_at: nil, active: true)
      audit_user_change!("administration.user.unlock")
      redirect_to backoffice_admin_users_path, notice: "Usuario #{@user.email} desbloqueado."
    end

    def apply_role_template
      template_key = params[:template_key].to_s
      template = Administration::RoleCatalog::ROLE_TEMPLATES[template_key]
      unless template && Administration::RoleCatalog.apply_template!(user: @user, template_key: template_key)
        redirect_to edit_backoffice_admin_user_path(@user), alert: "Plantilla de roles no valida."
        return
      end

      audit_user_change!(
        "administration.user_roles.update",
        template_key: template_key,
        template_name: template[:name],
        role_keys: template[:role_keys]
      )
      redirect_to edit_backoffice_admin_user_path(@user), notice: "Plantilla #{template[:name]} aplicada."
    end

    private

    def set_user
      @user = User.find(params[:id])
    end

    def load_role_form_data
      @role_matrix = Administration::RoleCatalog.role_matrix_grouped
      @role_templates = Administration::RoleCatalog::ROLE_TEMPLATES
      @superadmin_role = Role.find_by(key: Administration::RoleCatalog::SUPERADMIN_ROLE_KEY)
    end

    def user_params
      params.require(:user).permit(
        :email, :first_name, :last_name, :phone, :active,
        :password, :password_confirmation
      )
    end

    def superadmin_checked?
      ActiveModel::Type::Boolean.new.cast(params[:superadmin])
    end

    def removing_own_superadmin?
      @user.id == current_user.id && @user.has_role?(:superadmin) && !superadmin_checked?
    end

    def audit_user_change!(action, extra_metadata = {})
      AuditLog.record!(
        user: current_user,
        action: action,
        auditable: @user,
        metadata: {
          target_user_email: @user.email,
          active: @user.active,
          locked: @user.locked?
        }.merge(extra_metadata),
        ip_address: request.remote_ip,
        user_agent: request.user_agent
      )
    end
  end
end
