# frozen_string_literal: true

module Workspace
  class ApiClient
    BASE = {
      gmail: "https://gmail.googleapis.com/gmail/v1",
      calendar: "https://www.googleapis.com/calendar/v3",
      drive: "https://www.googleapis.com/drive/v3"
    }.freeze

    def initialize(connection)
      @connection = connection
      @oauth = Oauth.new(connection)
    end

    def get(service, path, params = {})
      request(:get, service, path, params: params)
    end

    def post(service, path, body = {})
      request(:post, service, path, body: body)
    end

    def patch(service, path, body = {})
      request(:patch, service, path, body: body)
    end

    def delete(service, path)
      request(:delete, service, path)
    end

    def upload_multipart(metadata:, file_io:, content_type:)
      token = @oauth.access_token!
      boundary = "amenti_#{SecureRandom.hex(8)}"
      file_bytes = file_io.read
      body = +""
      body << "--#{boundary}\r\n"
      body << "Content-Type: application/json; charset=UTF-8\r\n\r\n"
      body << metadata.to_json
      body << "\r\n--#{boundary}\r\n"
      body << "Content-Type: #{content_type}\r\n\r\n"
      body << file_bytes
      body << "\r\n--#{boundary}--\r\n"

      resp = Faraday.post(
        "https://www.googleapis.com/upload/drive/v3/files?uploadType=multipart&fields=id,name,webViewLink"
      ) do |req|
        req.headers["Authorization"] = "Bearer #{token}"
        req.headers["Content-Type"] = "multipart/related; boundary=#{boundary}"
        req.body = body
      end
      raise_api_error!("drive upload", resp) unless resp.success?

      JSON.parse(resp.body)
    end

    private

    def request(method, service, path, params: {}, body: nil)
      token = @oauth.access_token!
      base = BASE.fetch(service)
      conn = Faraday.new(url: base) do |f|
        f.request :json
        f.options.params_encoder = Faraday::FlatParamsEncoder
        f.adapter Faraday.default_adapter
      end

      resp = conn.run_request(method, path, body, {
        "Authorization" => "Bearer #{token}",
        "Accept" => "application/json"
      }) do |req|
        next if params.blank?

        params.each do |key, value|
          req.params[key.to_s] = value
        end
      end

      unless resp.success?
        @connection.mark_error!("#{service} #{path}: #{resp.status}")
        raise_api_error!(service, resp)
      end

      return {} if resp.body.blank?

      JSON.parse(resp.body)
    end

    def raise_api_error!(label, resp)
      raise "Workspace API error (#{label}): HTTP #{resp.status} #{resp.body.to_s.truncate(300)}"
    end
  end
end
