# frozen_string_literal: true

module Workspace
  class ImportGmailCorrespondences
    def initialize(lodge:, connection: nil, query: nil, max_results: 25)
      @lodge = lodge
      @connection = connection || WorkspaceConnection.google.find_by!(lodge: lodge)
      @query = query || Config.gmail_query
      @max_results = max_results
    end

    def call
      raise "Workspace no conectado" unless @connection.connected?

      gmail = GmailService.new(@connection)
      imported = 0
      skipped = 0

      gmail.list_message_ids(query: @query, max_results: @max_results).each do |message_id|
        if WorkspaceLink.exists?(provider: "google", resource_type: "gmail_message", external_id: message_id)
          skipped += 1
          next
        end

        message = gmail.get_message(message_id)
        headers = gmail.parse_headers(message)
        received_on = parse_date(headers[:date]) || Date.current
        sender = extract_email(headers[:from])

        correspondence = Correspondence.create!(
          lodge: @lodge,
          direction: "incoming",
          status: "draft",
          confidentiality_level: "internal",
          subject: headers[:subject].to_s.truncate(500),
          sender_name: sender.presence || headers[:from].to_s.truncate(200),
          received_on: received_on,
          summary: "Importado desde Gmail (#{message_id})"
        )

        WorkspaceLink.upsert_for!(
          lodge: @lodge,
          linkable: correspondence,
          resource_type: "gmail_message",
          external_id: message_id,
          external_url: gmail.message_web_url(message_id),
          metadata: {
            thread_id: message["threadId"],
            snippet: message["snippet"].to_s.truncate(280)
          }
        )
        imported += 1
      end

      @connection.update!(last_synced_at: Time.current, last_error: nil, status: "connected")
      { imported: imported, skipped: skipped }
    end

    private

    def parse_date(value)
      return if value.blank?

      Time.zone.parse(value).to_date
    rescue ArgumentError, TypeError
      nil
    end

    def extract_email(from_header)
      match = from_header.to_s.match(/<([^>]+)>/)
      match ? match[1] : from_header.to_s.strip
    end
  end
end
