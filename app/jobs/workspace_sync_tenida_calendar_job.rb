# frozen_string_literal: true

class WorkspaceSyncTenidaCalendarJob < ApplicationJob
  queue_as :default

  retry_on StandardError, wait: :polynomially_longer, attempts: 3
  discard_on ActiveRecord::RecordNotFound

  def perform(tenida_id)
    tenida = Tenida.find(tenida_id)
    Workspace::SyncTenidaCalendar.new(tenida: tenida).call
  rescue StandardError => e
    lodge_id = Tenida.where(id: tenida_id).pick(:lodge_id)
    WorkspaceConnection.google.find_by(lodge_id: lodge_id)&.mark_error!(e.message)
    raise
  end
end
