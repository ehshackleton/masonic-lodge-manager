# frozen_string_literal: true

class WorkspaceImportGmailJob < ApplicationJob
  queue_as :default

  retry_on StandardError, wait: :polynomially_longer, attempts: 3
  discard_on ActiveRecord::RecordNotFound

  def perform(lodge_id, query = nil)
    lodge = Lodge.find(lodge_id)
    result = Workspace::ImportGmailCorrespondences.new(lodge: lodge, query: query).call
    Rails.logger.info("[WorkspaceImportGmailJob] lodge=#{lodge_id} #{result.inspect}")
    result
  rescue StandardError => e
    connection = WorkspaceConnection.google.find_by(lodge_id: lodge_id)
    connection&.mark_error!(e.message)
    raise
  end
end
