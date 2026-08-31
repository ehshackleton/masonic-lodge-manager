# frozen_string_literal: true

module Backoffice
  class WorkspaceController < ApplicationController
    before_action :require_authentication
    before_action :require_current_lodge!
    before_action :authorize_workspace!

    def show
      @connection = connection_for_lodge
      @configured = Workspace::Config.enabled?
      @recent_gmail_links = WorkspaceLink.gmail_messages.where(lodge: current_lodge).order(created_at: :desc).limit(10)
    end

    def connect
      unless Workspace::Config.enabled?
        redirect_to backoffice_workspace_path, alert: "Configure GOOGLE_CLIENT_ID y GOOGLE_CLIENT_SECRET."
        return
      end

      state = SecureRandom.hex(24)
      session[:google_oauth_state] = state
      redirect_to Workspace::Oauth.authorization_url(state: state), allow_other_host: true
    end

    def callback
      if params[:state].blank? || params[:state] != session.delete(:google_oauth_state)
        redirect_to backoffice_workspace_path, alert: "Estado OAuth invalido. Reintente la conexion."
        return
      end

      if params[:error].present?
        redirect_to backoffice_workspace_path, alert: "Google denego el acceso: #{params[:error]}"
        return
      end

      token = Workspace::Oauth.exchange_code!(params[:code])
      conn = connection_for_lodge
      conn.access_token = token.token
      conn.refresh_token = token.refresh_token.presence || conn.refresh_token
      conn.expires_at = token.expires_at ? Time.zone.at(token.expires_at) : 55.minutes.from_now
      conn.save!

      oauth = Workspace::Oauth.new(conn)
      email = oauth.fetch_account_email
      conn.mark_connected!(email: email, scopes: Workspace::Config::SCOPES)

      AuditLog.record!(
        user: current_user,
        action: "workspace.connect",
        auditable: conn,
        metadata: { account_email: email },
        ip_address: request.remote_ip,
        user_agent: request.user_agent
      )

      redirect_to backoffice_workspace_path, notice: "Google Workspace conectado (#{email})."
    rescue StandardError => e
      connection_for_lodge.mark_error!(e.message)
      redirect_to backoffice_workspace_path, alert: "No se pudo completar OAuth: #{e.message.truncate(180)}"
    end

    def disconnect
      conn = connection_for_lodge
      conn.disconnect!
      AuditLog.record!(
        user: current_user,
        action: "workspace.disconnect",
        auditable: conn,
        metadata: {},
        ip_address: request.remote_ip,
        user_agent: request.user_agent
      )
      redirect_to backoffice_workspace_path, notice: "Conexion Google desvinculada."
    end

    def import_gmail
      conn = connection_for_lodge
      unless conn.connected?
        redirect_to backoffice_workspace_path, alert: "Conecte Google Workspace primero."
        return
      end

      result = WorkspaceImportGmailJob.perform_now(current_lodge.id, params[:q].presence)
      AuditLog.record!(
        user: current_user,
        action: "workspace.gmail.import",
        auditable: conn,
        metadata: result,
        ip_address: request.remote_ip,
        user_agent: request.user_agent
      )
      redirect_to backoffice_workspace_path,
                  notice: "Importacion Gmail: #{result[:imported]} nuevos, #{result[:skipped]} omitidos."
    rescue StandardError => e
      redirect_to backoffice_workspace_path, alert: "Error importando Gmail: #{e.message.truncate(180)}"
    end

    def health
      conn = connection_for_lodge
      unless conn.connected?
        redirect_to backoffice_workspace_path, alert: "Sin conexion activa."
        return
      end

      email = Workspace::Oauth.new(conn).fetch_account_email
      conn.update!(account_email: email, last_synced_at: Time.current, status: "connected", last_error: nil)
      redirect_to backoffice_workspace_path, notice: "Conexion viva (#{email})."
    rescue StandardError => e
      conn.mark_error!(e.message)
      redirect_to backoffice_workspace_path, alert: "Health check fallo: reconecte OAuth. #{e.message.truncate(120)}"
    end

    private

    def connection_for_lodge
      WorkspaceConnection.google.find_or_create_by!(lodge: current_lodge) do |c|
        c.status = "disconnected"
      end
    end

    def authorize_workspace!
      return if current_user&.has_role?(:superadmin) ||
                current_user&.has_role?(:secretario) ||
                current_user&.has_role?(:secretariat_manager)

      redirect_to "/backoffice", alert: "No tienes permisos para gestionar Google Workspace."
    end
  end
end
