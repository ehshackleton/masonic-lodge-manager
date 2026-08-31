# frozen_string_literal: true

class WorkspaceArchiveMinuteJob < ApplicationJob
  queue_as :default

  retry_on StandardError, wait: :polynomially_longer, attempts: 3
  discard_on ActiveRecord::RecordNotFound

  def perform(minute_id, force = false)
    minute = Minute.find(minute_id)
    Workspace::ArchiveMinuteToDrive.new(minute: minute).call(force: force)
  rescue StandardError => e
    lodge_id = Minute.where(id: minute_id).pick(:lodge_id)
    WorkspaceConnection.google.find_by(lodge_id: lodge_id)&.mark_error!(e.message)
    raise
  end
end
