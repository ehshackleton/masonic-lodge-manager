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
      Pdf::InstitutionalReport.new(
        title: "Acta #{@minute.folio}",
        subtitle: @minute.title,
        lodge: @lodge,
        meta_lines: [
          "Sesion: #{@minute.session_date}",
          "Estado: #{@minute.status.humanize}",
          "Visibilidad: #{@minute.visibility.humanize}"
        ],
        confidential: @minute.visibility != "public"
      ).render do |report, pdf|
        report.section(pdf, "Resumen") do
          report.paragraph(pdf, @minute.summary.to_s.presence || "Sin resumen.", muted: @minute.summary.blank?)
        end

        report.section(pdf, "Cuerpo") do
          report.paragraph(pdf, @minute.body.to_s.presence || "Sin contenido.", muted: @minute.body.blank?)
        end
      end
    end
  end
end
