module Backoffice
  class CorrespondencesController < ApplicationController
    before_action :require_authentication
    before_action :set_correspondence, only: %i[show edit update destroy submit_review approve publish]
    before_action :set_default_lodge, only: %i[new create]

    def index
      @q = params[:q].to_s.strip
      @status = params[:status].to_s.strip
      @direction = params[:direction].to_s.strip
      @correspondences = Correspondence.includes(:lodge).order(created_at: :desc)
      @correspondences = @correspondences.where(status: @status) if @status.present?
      @correspondences = @correspondences.where(direction: @direction) if @direction.present?
      if @q.present?
        pattern = "%#{@q.downcase}%"
        @correspondences = @correspondences.where("LOWER(subject) LIKE :q OR LOWER(folio) LIKE :q OR LOWER(sender_name) LIKE :q OR LOWER(recipient_name) LIKE :q", q: pattern)
      end
    end

    def export_excel
      load_correspondences_for_export
      rows = @correspondences.map do |c|
        %(<Row><Cell><Data ss:Type="String">#{ERB::Util.h(c.folio.to_s)}</Data></Cell><Cell><Data ss:Type="String">#{ERB::Util.h(c.subject.to_s)}</Data></Cell><Cell><Data ss:Type="String">#{ERB::Util.h(c.direction.humanize)}</Data></Cell><Cell><Data ss:Type="String">#{ERB::Util.h(c.status.humanize)}</Data></Cell><Cell><Data ss:Type="String">#{ERB::Util.h(c.confidentiality_level.humanize)}</Data></Cell></Row>)
      end.join("\n")
      xml = <<~XML
        <?xml version="1.0"?>
        <?mso-application progid="Excel.Sheet"?>
        <Workbook xmlns="urn:schemas-microsoft-com:office:spreadsheet"
          xmlns:o="urn:schemas-microsoft-com:office:office"
          xmlns:x="urn:schemas-microsoft-com:office:excel"
          xmlns:ss="urn:schemas-microsoft-com:office:spreadsheet">
          <Worksheet ss:Name="Correspondencia">
            <Table>
              <Row>
                <Cell><Data ss:Type="String">Folio</Data></Cell>
                <Cell><Data ss:Type="String">Asunto</Data></Cell>
                <Cell><Data ss:Type="String">Direccion</Data></Cell>
                <Cell><Data ss:Type="String">Estado</Data></Cell>
                <Cell><Data ss:Type="String">Confidencialidad</Data></Cell>
              </Row>
              #{rows}
            </Table>
          </Worksheet>
        </Workbook>
      XML
      send_data xml, filename: "correspondencia_#{Date.current}.xls", type: "application/vnd.ms-excel"
    end

    def export_pdf
      load_correspondences_for_export
      pdf = Prawn::Document.new(page_size: "A4")
      pdf.text "Reporte de correspondencia", size: 16, style: :bold
      pdf.move_down 8
      @correspondences.each do |c|
        pdf.text "#{c.folio} | #{c.subject}"
        pdf.text "Direccion: #{c.direction.humanize} | Estado: #{c.status.humanize} | Confidencialidad: #{c.confidentiality_level.humanize}", size: 10
        pdf.move_down 4
      end
      pdf.text "Sin correspondencia para exportar." if @correspondences.empty?
      send_data pdf.render, filename: "correspondencia_#{Date.current}.pdf", type: "application/pdf", disposition: "attachment"
    end

    def show; end

    def new
      @correspondence = Correspondence.new(status: "draft", direction: "incoming", confidentiality_level: "internal", lodge: @default_lodge)
    end

    def create
      @correspondence = Correspondence.new(correspondence_params)
      @correspondence.created_by_user = current_user
      if @correspondence.save
        attach_documents(@correspondence)
        audit_action("correspondence.create", @correspondence, subject: @correspondence.subject, folio: @correspondence.folio, status: @correspondence.status)
        redirect_to backoffice_correspondence_path(@correspondence), notice: "Correspondencia creada."
      else
        render :new, status: :unprocessable_entity
      end
    end

    def edit; end

    def update
      previous_status = @correspondence.status
      if @correspondence.update(correspondence_params)
        attach_documents(@correspondence)
        audit_action("correspondence.update", @correspondence, subject: @correspondence.subject, folio: @correspondence.folio, status_from: previous_status, status_to: @correspondence.status)
        redirect_to backoffice_correspondence_path(@correspondence), notice: "Correspondencia actualizada."
      else
        render :edit, status: :unprocessable_entity
      end
    end

    def destroy
      audit_action("correspondence.destroy", @correspondence, subject: @correspondence.subject, folio: @correspondence.folio, status: @correspondence.status)
      @correspondence.destroy
      redirect_to backoffice_correspondences_path, notice: "Correspondencia eliminada."
    end

    def submit_review
      return invalid_workflow_transition unless @correspondence.can_submit_review?

      @correspondence.update!(status: "review")
      audit_action("correspondence.submit_review", @correspondence, folio: @correspondence.folio, status_to: "review")
      redirect_to backoffice_correspondence_path(@correspondence), notice: "Correspondencia enviada a revision."
    end

    def approve
      return invalid_workflow_transition unless @correspondence.can_approve?

      @correspondence.update!(status: "approved")
      audit_action("correspondence.approve", @correspondence, folio: @correspondence.folio, status_to: "approved")
      redirect_to backoffice_correspondence_path(@correspondence), notice: "Correspondencia aprobada."
    end

    def publish
      return invalid_workflow_transition unless @correspondence.can_publish?

      @correspondence.update!(status: "published")
      audit_action("correspondence.publish", @correspondence, folio: @correspondence.folio, status_to: "published")
      redirect_to backoffice_correspondence_path(@correspondence), notice: "Correspondencia publicada."
    end

    private

    def set_correspondence
      @correspondence = Correspondence.find(params[:id])
    end

    def set_default_lodge
      @default_lodge = Lodge.first
    end

    def correspondence_params
      params.require(:correspondence).permit(
        :lodge_id, :direction, :document_type, :folio, :subject, :sender_name, :recipient_name,
        :sent_on, :received_on, :summary, :body, :confidentiality_level, documents: []
      )
    end

    def attach_documents(correspondence)
      return unless params.dig(:correspondence, :documents).present?
      correspondence.documents.attach(params[:correspondence][:documents])
    end

    def load_correspondences_for_export
      @correspondences = Correspondence.order(created_at: :desc)
      @correspondences = @correspondences.where(status: params[:status]) if params[:status].present?
      @correspondences = @correspondences.where(direction: params[:direction]) if params[:direction].present?
      if params[:q].present?
        pattern = "%#{params[:q].to_s.strip.downcase}%"
        @correspondences = @correspondences.where("LOWER(subject) LIKE :q OR LOWER(folio) LIKE :q OR LOWER(sender_name) LIKE :q OR LOWER(recipient_name) LIKE :q", q: pattern)
      end
    end

    def audit_action(action, auditable, metadata = {})
      AuditLog.record!(
        user: current_user,
        action: action,
        auditable: auditable,
        metadata: metadata,
        ip_address: request.remote_ip,
        user_agent: request.user_agent
      )
    end

    def invalid_workflow_transition
      redirect_to backoffice_correspondence_path(@correspondence), alert: "Transicion de workflow no permitida."
    end
  end
end
