# frozen_string_literal: true

module Workspace
  class GmailService
    def initialize(connection)
      @client = ApiClient.new(connection)
      @connection = connection
    end

    def list_message_ids(query: Config.gmail_query, max_results: 25)
      data = @client.get(:gmail, "users/me/messages", q: query, maxResults: max_results)
      Array(data["messages"]).map { |m| m["id"] }
    end

    def get_message(message_id)
      @client.get(
        :gmail,
        "users/me/messages/#{message_id}",
        format: "metadata",
        metadataHeaders: %w[From Subject Date]
      )
    end

    def message_web_url(message_id)
      "https://mail.google.com/mail/u/0/#inbox/#{message_id}"
    end

    def parse_headers(message)
      headers = Array(message.dig("payload", "headers"))
      find = ->(name) { headers.find { |h| h["name"].to_s.casecmp?(name) }&.dig("value") }
      {
        subject: find.call("Subject").presence || "(sin asunto)",
        from: find.call("From").to_s,
        date: find.call("Date")
      }
    end
  end
end
