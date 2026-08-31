# frozen_string_literal: true

module Workspace
  class Config
    SCOPES = [
      "https://www.googleapis.com/auth/gmail.readonly",
      "https://www.googleapis.com/auth/calendar.events",
      "https://www.googleapis.com/auth/drive.file",
      "openid",
      "email",
      "profile"
    ].freeze

    class << self
      def enabled?
        client_id.present? && client_secret.present?
      end

      def client_id
        ENV["GOOGLE_CLIENT_ID"].to_s.presence
      end

      def client_secret
        ENV["GOOGLE_CLIENT_SECRET"].to_s.presence
      end

      def redirect_uri
        ENV.fetch("GOOGLE_OAUTH_REDIRECT_URI") do
          host = ENV.fetch("APP_HOST", "localhost:3000")
          protocol = host.include?("localhost") ? "http" : "https"
          "#{protocol}://#{host}/backoffice/workspace/callback"
        end
      end

      def gmail_query
        ENV.fetch("GOOGLE_GMAIL_QUERY", "in:inbox newer_than:30d")
      end

      def drive_folder_id
        ENV["GOOGLE_DRIVE_FOLDER_ID"].to_s.presence
      end

      def institutional_email
        ENV.fetch("GOOGLE_INSTITUTIONAL_EMAIL", "amentidiez31@granlogiamixta.cl")
      end
    end
  end
end
