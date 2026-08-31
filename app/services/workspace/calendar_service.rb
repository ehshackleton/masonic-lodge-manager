# frozen_string_literal: true

module Workspace
  class CalendarService
    def initialize(connection)
      @client = ApiClient.new(connection)
    end

    def upsert_tenida_event(tenida, existing_event_id: nil)
      body = event_body(tenida)
      if existing_event_id.present?
        @client.patch(:calendar, "calendars/primary/events/#{existing_event_id}", body)
      else
        @client.post(:calendar, "calendars/primary/events", body)
      end
    end

    def cancel_event(event_id)
      return if event_id.blank?

      @client.delete(:calendar, "calendars/primary/events/#{event_id}")
    rescue StandardError
      # Best-effort: evento puede ya no existir
      nil
    end

    private

    def event_body(tenida)
      start_date = tenida.held_on
      {
        summary: "Tenida #{tenida.code} — Amenti Diez N°31",
        description: [
          "Tipo: #{tenida.tenida_type}",
          ("Grado: #{tenida.degree&.name}" if tenida.degree),
          ("Lugar: #{tenida.place}" if tenida.place.present?),
          ("Notas: #{tenida.notes}" if tenida.notes.present?),
          "Gestionado desde logia.amenti.cl"
        ].compact.join("\n"),
        start: { date: start_date.iso8601 },
        end: { date: (start_date + 1.day).iso8601 },
        status: tenida.status_cancelled? ? "cancelled" : "confirmed"
      }
    end
  end
end
