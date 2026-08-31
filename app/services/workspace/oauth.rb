# frozen_string_literal: true

require "oauth2"

module Workspace
  class Oauth
    AUTHORIZE_URL = "https://accounts.google.com/o/oauth2/v2/auth"
    TOKEN_URL = "https://oauth2.googleapis.com/token"

    def self.client
      raise "Google OAuth no configurado (GOOGLE_CLIENT_ID/SECRET)" unless Config.enabled?

      OAuth2::Client.new(
        Config.client_id,
        Config.client_secret,
        site: "https://oauth2.googleapis.com",
        authorize_url: AUTHORIZE_URL,
        token_url: TOKEN_URL
      )
    end

    def self.authorization_url(state:)
      client.auth_code.authorize_url(
        redirect_uri: Config.redirect_uri,
        scope: Config::SCOPES.join(" "),
        access_type: "offline",
        prompt: "consent",
        include_granted_scopes: true,
        state: state
      )
    end

    def self.exchange_code!(code)
      client.auth_code.get_token(code, redirect_uri: Config.redirect_uri)
    end

    def initialize(connection)
      @connection = connection
    end

    def access_token!
      refresh_if_needed!
      @connection.access_token
    end

    def refresh_if_needed!
      return unless @connection.refresh_token.present?
      return if @connection.access_token.present? && !@connection.expired?

      token = OAuth2::AccessToken.new(
        self.class.client,
        @connection.access_token,
        refresh_token: @connection.refresh_token
      )
      new_token = token.refresh!
      @connection.update!(
        access_token: new_token.token,
        refresh_token: new_token.refresh_token.presence || @connection.refresh_token,
        expires_at: new_token.expires_at ? Time.zone.at(new_token.expires_at) : 55.minutes.from_now,
        status: "connected",
        last_error: nil
      )
    rescue OAuth2::Error => e
      @connection.mark_error!(e.message)
      raise
    end

    def fetch_account_email
      resp = Faraday.get("https://openidconnect.googleapis.com/v1/userinfo") do |req|
        req.headers["Authorization"] = "Bearer #{access_token!}"
      end
      raise "No se pudo obtener el perfil Google (#{resp.status})" unless resp.success?

      JSON.parse(resp.body)["email"]
    end
  end
end
