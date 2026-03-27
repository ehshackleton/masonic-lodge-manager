module Backoffice
  class MinutesController < ApplicationController
    before_action :require_authentication
    before_action :set_minute, only: %i[show edit update destroy submit_review approve publish]
    before_action :authorize_minutes_read_access!
    before_action :authorize_minutes_write_access!, only: %i[new create edit update destroy submit_review]
    before_action :authorize_minutes_approval_access!, only: %i[approve publish]

    def index
      @q = params[:q].to_s.strip
      @status = params[:status].to_s.strip
      @minutes = Minute.order(session_date: :desc)
      @minutes = @minutes.where(status: @status) if @status.present?
      if @q.present?
        pattern = "%#{@q.downcase}%"
        @minutes = @minutes.where("LOWER(title) LIKE :q OR LOWER(folio) LIKE :q", q: pattern)
      end
    end

    def export_excel
      load_minutes_for_export
      rows = @minutes.map do |m|
        %(<Row><Cell><Data ss:Type="String">#{ERB::Util.h(m.folio.to_s)}</Data></Cell><Cell><Data ss:Type="String">#{ERB::Util.h(m.session_date.to_s)}</Data></Cell><Cell><Data ss:Type="String">#{ERB::Util.h(m.title.to_s)}</Data></Cell><Cell><Data ss:Type="String">#{ERB::Util.h(m.status.humanize)}</Data></Cell><Cell><Data ss:Type="String">#{ERB::Util.h(m.visibility.humanize)}</Data></Cell></Row>)
      end.join("\n")

      xml = <<~XML
        <?xml version="1.0"?>
        <?mso-application progid="Excel.Sheet"?>
        <Workbook xmlns="urn:schemas-microsoft-com:office:spreadsheet"
          xmlns:o="urn:schemas-microsoft-com:office:office"
          xmlns:x="urn:schemas-microsoft-com:office:excel"
          xmlns:ss="urn:schemas-microsoft-com:office:spreadsheet">
          <Worksheet ss:Name="Actas">
            <Table>
              <Row>
                <Cell><Data ss:Type="String">Folio</Data></Cell>
                <Cell><Data ss:Type="String">Sesion</Data></Cell>
                <Cell><Data ss:Type="String">Titulo</Data></Cell>
                <Cell><Data ss:Type="String">Estado</Data></Cell>
                <Cell><Data ss:Type="String">Visibilidad</Data></Cell>
              </Row>
              #{rows}
            </Table>
          </Worksheet>
        </Workbook>
      XML
      send_data xml, filename: "actas_#{Date.current}.xls", type: "application/vnd.ms-excel"
    end

    def export_pdf
      load_minutes_for_export
      pdf = Prawn::Document.new(page_size: "A4")
      pdf.text "Reporte de actas", size: 16, style: :bold
      pdf.move_down 8
      @minutes.each do |m|
        pdf.text "#{m.folio} | #{m.session_date} | #{m.title}"
        pdf.text "Estado: #{m.status.humanize} | Visibilidad: #{m.visibility.humanize}", size: 10
        pdf.move_down 4
      end
      pdf.text "Sin actas para exportar." if @minutes.empty?
      send_data pdf.render, filename: "actas_#{Date.current}.pdf", type: "application/pdf", disposition: "attachment"
    end

    def show; end

    def new
      @minute = Minute.new(session_date: Date.current, status: "draft", visibility: "internal")
    end

    def create
      @minute = Minute.new(minute_params)
      @minute.created_by_user = current_user
      if @minute.save
        attach_documents(@minute)
        audit_action("minute.create", @minute, title: @minute.title, folio: @minute.folio, status: @minute.status)
        redirect_to backoffice_minute_path(@minute), notice: "Acta creada."
      else
        render :new, status: :unprocessable_entity
      end
    end

    def edit; end

    def update
      previous_status = @minute.status
      if @minute.update(minute_params)
        attach_documents(@minute)
        audit_action("minute.update", @minute, title: @minute.title, folio: @minute.folio, status_from: previous_status, status_to: @minute.status)
        redirect_to backoffice_minute_path(@minute), notice: "Acta actualizada."
      else
        render :edit, status: :unprocessable_entity
      end
    end

    def destroy
      audit_action("minute.destroy", @minute, title: @minute.title, folio: @minute.folio, status: @minute.status)
      @minute.destroy
      redirect_to backoffice_minutes_path, notice: "Acta eliminada."
    end

    def submit_review
      return invalid_workflow_transition unless @minute.can_submit_review?

      @minute.update!(status: "review")
      audit_action("minute.submit_review", @minute, folio: @minute.folio, status_to: "review")
      redirect_to backoffice_minute_path(@minute), notice: "Acta enviada a revision."
    end

    def approve
      return invalid_workflow_transition unless @minute.can_approve?

      @minute.update!(status: "approved")
      audit_action("minute.approve", @minute, folio: @minute.folio, status_to: "approved")
      redirect_to backoffice_minute_path(@minute), notice: "Acta aprobada."
    end

    def publish
      return invalid_workflow_transition unless @minute.can_publish?

      @minute.update!(status: "published")
      audit_action("minute.publish", @minute, folio: @minute.folio, status_to: "published")
      redirect_to backoffice_minute_path(@minute), notice: "Acta publicada."
    end

    private

    def set_minute
      @minute = Minute.find(params[:id])
    end

    def minute_params
      params.require(:minute).permit(:title, :session_date, :folio, :summary, :body, :visibility, documents: [])
    end

    def attach_documents(minute)
      return unless params.dig(:minute, :documents).present?
      minute.documents.attach(params[:minute][:documents])
    end

    def load_minutes_for_export
      @minutes = Minute.order(session_date: :desc)
      @minutes = @minutes.where(status: params[:status]) if params[:status].present?
      if params[:q].present?
        pattern = "%#{params[:q].to_s.strip.downcase}%"
        @minutes = @minutes.where("LOWER(title) LIKE :q OR LOWER(folio) LIKE :q", q: pattern)
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
      redirect_to backoffice_minute_path(@minute), alert: "Transicion de workflow no permitida."
    end

    def authorize_minutes_read_access!
      return if current_user&.can_access_module?(:secretariat) && current_user&.can_manage_secretariat_action?(:minutes_read)

      audit_permission_denied("minutes_read")
      redirect_to "/backoffice", alert: "No tienes permisos para acceder al modulo de actas."
    end

    def authorize_minutes_write_access!
      return if current_user&.can_manage_secretariat_action?(:minute_write)

      audit_permission_denied("minute_write")
      redirect_to "/backoffice/minutes", alert: "No tienes permisos para crear/editar actas."
    end

    def authorize_minutes_approval_access!
      return if current_user&.can_manage_secretariat_action?(:minute_approve)

      audit_permission_denied("minute_approve")
      redirect_to "/backoffice/minutes", alert: "No tienes permisos para aprobar/publicar actas."
    end

    def audit_permission_denied(denied_action)
      AuditLog.record!(
        user: current_user,
        action: "permission.denied.secretariat.minute",
        auditable: @minute || current_user,
        metadata: { denied_action: denied_action, path: request.path, method: request.request_method },
        ip_address: request.remote_ip,
        user_agent: request.user_agent
      )
    end
  end
end
