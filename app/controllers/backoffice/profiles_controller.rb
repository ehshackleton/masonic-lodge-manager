module Backoffice
  class ProfilesController < ApplicationController
    before_action :require_authentication

    def show
      @user = current_user
    end

    def update
      @user = current_user
      attrs = profile_params.to_h

      password = attrs.delete("password")
      password_confirmation = attrs.delete("password_confirmation")

      if password.present?
        attrs["password"] = password
        attrs["password_confirmation"] = password_confirmation
      end

      if @user.update(attrs)
        attach_avatar(@user)
        AuditLog.record!(
          user: current_user,
          action: "user.profile.update",
          auditable: @user,
          metadata: { updated_fields: attrs.keys },
          ip_address: request.remote_ip,
          user_agent: request.user_agent
        )
        redirect_to "/backoffice/perfil", notice: "Perfil actualizado."
      else
        render :show, status: :unprocessable_entity
      end
    end

    def destroy_avatar
      @user = current_user
      if @user.avatar.attached?
        @user.avatar.purge
        AuditLog.record!(
          user: current_user,
          action: "user.profile.avatar.delete",
          auditable: @user,
          metadata: {},
          ip_address: request.remote_ip,
          user_agent: request.user_agent
        )
      end
      redirect_to "/backoffice/perfil", notice: "Foto de perfil eliminada."
    end

    private

    def profile_params
      params.require(:user).permit(
        :first_name, :last_name, :phone, :locale, :time_zone, :bio,
        :password, :password_confirmation, :avatar
      )
    end

    def attach_avatar(user)
      return unless params.dig(:user, :avatar).present?
      user.avatar.attach(params[:user][:avatar])
    end
  end
end
