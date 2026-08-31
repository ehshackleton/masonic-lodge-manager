# frozen_string_literal: true

module Workspace
  class DriveService
    def initialize(connection)
      @client = ApiClient.new(connection)
    end

    def upload_minute_pdf(minute, pdf_bytes:, filename:)
      parents = []
      parents << Config.drive_folder_id if Config.drive_folder_id

      year = (minute.session_date || Date.current).year
      month = format("%02d", (minute.session_date || Date.current).month)
      # Con drive.file no listamos/creamos árbol complejo sin folder id; metadatos llevan nombre con ruta lógica
      logical_name = "Actas/#{year}/#{month}/#{filename}"

      metadata = {
        name: logical_name,
        mimeType: "application/pdf"
      }
      metadata[:parents] = parents if parents.any?

      @client.upload_multipart(
        metadata: metadata,
        file_io: StringIO.new(pdf_bytes),
        content_type: "application/pdf"
      )
    end
  end
end
