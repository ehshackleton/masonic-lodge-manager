# frozen_string_literal: true

module Workspace
  class SyncTenidaCalendar
    def initialize(tenida:)
      @tenida = tenida
      @lodge = tenida.lodge
      @connection = WorkspaceConnection.google.find_by(lodge: @lodge)
    end

    def call
      return { skipped: true, reason: "no_connection" } unless @connection&.connected?

      existing = WorkspaceLink.calendar_events.find_by(linkable: @tenida)
      calendar = CalendarService.new(@connection)

      if @tenida.status_cancelled?
        calendar.cancel_event(existing&.external_id)
        existing&.destroy
        return { cancelled: true }
      end

      event = calendar.upsert_tenida_event(@tenida, existing_event_id: existing&.external_id)
      event_id = event["id"]
      url = event["htmlLink"]

      WorkspaceLink.upsert_for!(
        lodge: @lodge,
        linkable: @tenida,
        resource_type: "calendar_event",
        external_id: event_id,
        external_url: url,
        metadata: { status: event["status"] }
      )
      { event_id: event_id }
    end
  end
end
