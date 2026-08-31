# frozen_string_literal: true

module Workspace
  class ArchiveMinuteToDrive
    def initialize(minute:)
      @minute = minute
      @lodge = minute.lodge
      @connection = WorkspaceConnection.google.find_by(lodge: @lodge)
    end

    def call(force: false)
      return { skipped: true, reason: "no_connection" } unless @connection&.connected?

      existing = WorkspaceLink.drive_files.find_by(linkable: @minute)
      if existing && !force
        return { skipped: true, reason: "already_archived", drive_file_id: existing.external_id, url: existing.external_url }
      end

      pdf = build_pdf
      filename = "#{@minute.folio.presence || "acta-#{@minute.id}"}.pdf"
      drive = DriveService.new(@connection)
      file = drive.upload_minute_pdf(@minute, pdf_bytes: pdf, filename: filename)

      WorkspaceLink.upsert_for!(
        lodge: @lodge,
        linkable: @minute,
        resource_type: "drive_file",
        external_id: file["id"],
        external_url: file["webViewLink"],
        metadata: { name: file["name"] }
      )
      { drive_file_id: file["id"], url: file["webViewLink"] }
    end

    private

    def build_pdf
      require "prawn"
      PrawnDocument.build do |pdf|
        pdf.text "Acta #{@minute.folio}", size: 16, style: :bold
        pdf.move_down 8
        pdf.text "Titulo: #{@minute.title}"
        pdf.text "Sesion: #{@minute.session_date}"
        pdf.text "Estado: #{@minute.status}"
        pdf.text "Visibilidad: #{@minute.visibility}"
        pdf.move_down 10
        pdf.text "Resumen", style: :bold
        pdf.text @minute.summary.to_s
        pdf.move_down 10
        pdf.text "Cuerpo", style: :bold
        pdf.text @minute.body.to_s
      end.render
    end
  end
end
