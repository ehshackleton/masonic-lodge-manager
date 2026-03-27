module Backoffice
  class MasonicWorksController < ApplicationController
    before_action :require_authentication
    before_action :authorize_works_module_access!
    before_action :set_masonic_work, only: %i[show edit update destroy submit_review approve mark_presented archive]
    before_action :load_collections, only: %i[new edit create update]
    before_action only: :submit_review do
      authorize_masonic_work_action!(:submit_review)
    end
    before_action only: :approve do
      authorize_masonic_work_action!(:approve)
    end
    before_action only: :mark_presented do
      authorize_masonic_work_action!(:mark_presented)
    end
    before_action only: :archive do
      authorize_masonic_work_action!(:archive)
    end

    def index
      @q = params[:q].to_s.strip
      @status = params[:status].to_s.strip
      @brother_id = params[:brother_id].to_s.strip
      @period_from = parse_date(params[:period_from]) || Date.current.beginning_of_month
      @period_to = parse_date(params[:period_to]) || Date.current.end_of_month

      @masonic_works = MasonicWork.includes(:brother, :degree, :reviewer_user).order(created_at: :desc)
      @masonic_works = @masonic_works.where(status: @status) if @status.present?
      @masonic_works = @masonic_works.where(brother_id: @brother_id) if @brother_id.present?
      if @q.present?
        pattern = "%#{@q.downcase}%"
        @masonic_works = @masonic_works.where("LOWER(title) LIKE :q OR LOWER(topic) LIKE :q", q: pattern)
      end

      load_productivity_dashboard
      build_monthly_productivity_series
    end

    def export_excel
      load_works_for_export
      rows = @works_for_export.map do |work|
        %(<Row><Cell><Data ss:Type="String">#{ERB::Util.h(work.title.to_s)}</Data></Cell><Cell><Data ss:Type="String">#{ERB::Util.h(work.brother&.full_name.to_s)}</Data></Cell><Cell><Data ss:Type="String">#{ERB::Util.h(work.status.humanize)}</Data></Cell><Cell><Data ss:Type="String">#{ERB::Util.h(work.assigned_on.to_s)}</Data></Cell><Cell><Data ss:Type="String">#{ERB::Util.h(work.due_on.to_s)}</Data></Cell><Cell><Data ss:Type="String">#{ERB::Util.h(work.reviewer_user&.email.to_s)}</Data></Cell></Row>)
      end.join("\n")
      xml = <<~XML
        <?xml version="1.0"?>
        <?mso-application progid="Excel.Sheet"?>
        <Workbook xmlns="urn:schemas-microsoft-com:office:spreadsheet"
          xmlns:o="urn:schemas-microsoft-com:office:office"
          xmlns:x="urn:schemas-microsoft-com:office:excel"
          xmlns:ss="urn:schemas-microsoft-com:office:spreadsheet">
          <Worksheet ss:Name="Trabajos">
            <Table>
              <Row>
                <Cell><Data ss:Type="String">Trabajo</Data></Cell>
                <Cell><Data ss:Type="String">Hermano</Data></Cell>
                <Cell><Data ss:Type="String">Estado</Data></Cell>
                <Cell><Data ss:Type="String">Asignacion</Data></Cell>
                <Cell><Data ss:Type="String">Compromiso</Data></Cell>
                <Cell><Data ss:Type="String">Revisor</Data></Cell>
              </Row>
              #{rows}
            </Table>
          </Worksheet>
        </Workbook>
      XML
      send_data xml, filename: "trabajos_masonicos_#{Date.current}.xls", type: "application/vnd.ms-excel"
    end

    def export_pdf
      load_works_for_export
      pdf = Prawn::Document.new(page_size: "A4")
      pdf.text "Reporte de trabajos masonicos", size: 16, style: :bold
      pdf.move_down 8
      @works_for_export.each do |work|
        pdf.text "#{work.title} | #{work.brother&.full_name}"
        pdf.text "Estado: #{work.status.humanize} | Asignado: #{work.assigned_on || '-'} | Compromiso: #{work.due_on || '-'}", size: 10
        pdf.move_down 4
      end
      pdf.text "Sin trabajos para exportar." if @works_for_export.empty?
      send_data pdf.render, filename: "trabajos_masonicos_#{Date.current}.pdf", type: "application/pdf", disposition: "attachment"
    end

    def export_reviews_excel
      load_reviews_for_export
      rows = @reviews_for_export.map do |review|
        %(<Row><Cell><Data ss:Type="String">#{ERB::Util.h(review.masonic_work&.title.to_s)}</Data></Cell><Cell><Data ss:Type="String">#{ERB::Util.h(review.reviewer_user&.email.to_s)}</Data></Cell><Cell><Data ss:Type="String">#{ERB::Util.h(review.reviewed_on.to_s)}</Data></Cell><Cell><Data ss:Type="String">#{ERB::Util.h(review.status.humanize)}</Data></Cell><Cell><Data ss:Type="String">#{ERB::Util.h(review.comments.to_s)}</Data></Cell></Row>)
      end.join("\n")
      xml = <<~XML
        <?xml version="1.0"?>
        <?mso-application progid="Excel.Sheet"?>
        <Workbook xmlns="urn:schemas-microsoft-com:office:spreadsheet"
          xmlns:o="urn:schemas-microsoft-com:office:office"
          xmlns:x="urn:schemas-microsoft-com:office:excel"
          xmlns:ss="urn:schemas-microsoft-com:office:spreadsheet">
          <Worksheet ss:Name="Revisiones">
            <Table>
              <Row>
                <Cell><Data ss:Type="String">Trabajo</Data></Cell>
                <Cell><Data ss:Type="String">Revisor</Data></Cell>
                <Cell><Data ss:Type="String">Fecha</Data></Cell>
                <Cell><Data ss:Type="String">Estado</Data></Cell>
                <Cell><Data ss:Type="String">Comentarios</Data></Cell>
              </Row>
              #{rows}
            </Table>
          </Worksheet>
        </Workbook>
      XML
      send_data xml, filename: "revisiones_trabajos_#{Date.current}.xls", type: "application/vnd.ms-excel"
    end

    def export_reviews_pdf
      load_reviews_for_export
      pdf = Prawn::Document.new(page_size: "A4")
      pdf.text "Reporte de revisiones de trabajos", size: 16, style: :bold
      pdf.move_down 8
      @reviews_for_export.each do |review|
        pdf.text "#{review.reviewed_on} | #{review.masonic_work&.title}"
        pdf.text "Revisor: #{review.reviewer_user&.email} | Resultado: #{review.status.humanize}", size: 10
        pdf.text "Comentarios: #{review.comments.presence || '-'}", size: 10
        pdf.move_down 4
      end
      pdf.text "Sin revisiones para exportar." if @reviews_for_export.empty?
      send_data pdf.render, filename: "revisiones_trabajos_#{Date.current}.pdf", type: "application/pdf", disposition: "attachment"
    end

    def export_dashboard_pdf
      @q = params[:q].to_s.strip
      @status = params[:status].to_s.strip
      @brother_id = params[:brother_id].to_s.strip
      @period_from = parse_date(params[:period_from]) || Date.current.beginning_of_month
      @period_to = parse_date(params[:period_to]) || Date.current.end_of_month
      load_productivity_dashboard
      build_monthly_productivity_series
      load_works_for_export

      pdf = Prawn::Document.new(page_size: "A4")
      pdf.text "Tablero de productividad - Trabajos masonicos", size: 16, style: :bold
      pdf.move_down 4
      pdf.text "Periodo: #{@period_from} a #{@period_to}", size: 10
      pdf.text "Filtros: estado=#{@status.presence || 'todos'} | hermano_id=#{@brother_id.presence || 'todos'} | busqueda=#{@q.presence || '-'}", size: 9
      pdf.move_down 10

      pdf.text "Resumen KPI", style: :bold, size: 12
      pdf.text "Pendientes: #{@productivity_pending}"
      pdf.text "Aprobados: #{@productivity_approved}"
      pdf.text "Presentados: #{@productivity_presented}"
      pdf.text "Vencidos: #{@productivity_overdue}"
      pdf.move_down 10

      pdf.text "Productividad mensual (12 meses)", style: :bold, size: 12
      @monthly_productivity_series.each do |row|
        pdf.text "#{row[:label]} | Creados: #{row[:created]} | Aprobados: #{row[:approved]} | Presentados: #{row[:presented]}", size: 9
      end
      pdf.move_down 10

      pdf.text "Detalle de trabajos", style: :bold, size: 12
      @works_for_export.limit(200).each do |work|
        pdf.text "#{work.title} | #{work.brother&.full_name}", size: 10
        pdf.text "Estado: #{work.status.humanize} | Asignado: #{work.assigned_on || '-'} | Compromiso: #{work.due_on || '-'} | Revisor: #{work.reviewer_user&.email || '-'}", size: 9
        pdf.move_down 3
      end
      pdf.text "Sin trabajos para detallar." if @works_for_export.empty?

      send_data pdf.render, filename: "tablero_trabajos_masonicos_#{Date.current}.pdf", type: "application/pdf", disposition: "attachment"
    end

    def show
      @work_reviews = @masonic_work.work_reviews.includes(:reviewer_user).order(reviewed_on: :desc, created_at: :desc)
      @work_review = @masonic_work.work_reviews.new(reviewed_on: Date.current, reviewer_user: current_user)
      @audit_logs = AuditLog.where(auditable_type: "MasonicWork", auditable_id: @masonic_work.id).includes(:user).order(created_at: :desc).limit(20)
    end

    def new
      @masonic_work = MasonicWork.new(
        lodge: Lodge.first,
        assigned_on: Date.current,
        status: "assigned"
      )
    end

    def create
      @masonic_work = MasonicWork.new(masonic_work_params)
      @masonic_work.status ||= "assigned"
      if @masonic_work.save
        attach_documents(@masonic_work)
        audit_action("masonic_work.create", @masonic_work, title: @masonic_work.title, status: @masonic_work.status)
        redirect_to backoffice_masonic_work_path(@masonic_work), notice: "Trabajo masonico creado."
      else
        render :new, status: :unprocessable_entity
      end
    end

    def edit; end

    def update
      previous_status = @masonic_work.status
      if @masonic_work.update(masonic_work_params)
        attach_documents(@masonic_work)
        audit_action("masonic_work.update", @masonic_work, title: @masonic_work.title, status_from: previous_status, status_to: @masonic_work.status)
        redirect_to backoffice_masonic_work_path(@masonic_work), notice: "Trabajo masonico actualizado."
      else
        render :edit, status: :unprocessable_entity
      end
    end

    def destroy
      audit_action("masonic_work.destroy", @masonic_work, title: @masonic_work.title, status: @masonic_work.status)
      @masonic_work.destroy
      redirect_to backoffice_masonic_works_path, notice: "Trabajo masonico eliminado."
    end

    def submit_review
      return invalid_workflow_transition unless @masonic_work.can_submit_review?

      @masonic_work.update!(status: "in_review")
      audit_action("masonic_work.submit_review", @masonic_work, status_to: "in_review")
      redirect_to backoffice_masonic_work_path(@masonic_work), notice: "Trabajo enviado a revision."
    end

    def approve
      return invalid_workflow_transition unless @masonic_work.can_approve?

      @masonic_work.update!(status: "approved")
      audit_action("masonic_work.approve", @masonic_work, status_to: "approved")
      redirect_to backoffice_masonic_work_path(@masonic_work), notice: "Trabajo aprobado."
    end

    def mark_presented
      return invalid_workflow_transition unless @masonic_work.can_mark_presented?

      @masonic_work.update!(status: "presented", presented_on: Date.current)
      audit_action("masonic_work.mark_presented", @masonic_work, status_to: "presented", presented_on: Date.current)
      redirect_to backoffice_masonic_work_path(@masonic_work), notice: "Trabajo marcado como presentado."
    end

    def archive
      return invalid_workflow_transition unless @masonic_work.can_archive?

      @masonic_work.update!(status: "archived")
      audit_action("masonic_work.archive", @masonic_work, status_to: "archived")
      redirect_to backoffice_masonic_work_path(@masonic_work), notice: "Trabajo archivado."
    end

    private

    def set_masonic_work
      @masonic_work = MasonicWork.find(params[:id])
    end

    def load_collections
      @lodges = Lodge.order(:name)
      @brothers = Brother.order(:last_name, :first_name)
      @degrees = Degree.order(:name)
      @reviewers = User.order(:email)
    end

    def masonic_work_params
      params.require(:masonic_work).permit(
        :lodge_id, :brother_id, :degree_id, :reviewer_user_id, :title, :topic, :assigned_on, :due_on,
        :presented_on, :abstract, :body, :private_notes, documents: []
      )
    end

    def attach_documents(work)
      return unless params.dig(:masonic_work, :documents).present?
      work.documents.attach(params[:masonic_work][:documents])
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
      redirect_to backoffice_masonic_work_path(@masonic_work), alert: "Transicion de workflow no permitida."
    end

    def authorize_masonic_work_action!(action)
      return if current_user&.can_manage_masonic_work_action?(action)

      audit_permission_denial(action)
      redirect_to backoffice_masonic_work_path(@masonic_work), alert: "No tienes permisos para esta accion."
    end

    def audit_permission_denial(action)
      AuditLog.record!(
        user: current_user,
        action: "permission.denied.masonic_work",
        auditable: @masonic_work,
        metadata: {
          denied_action: action.to_s,
          path: request.path,
          method: request.request_method
        },
        ip_address: request.remote_ip,
        user_agent: request.user_agent
      )
    end

    def authorize_works_module_access!
      return if current_user&.can_access_module?(:works)

      AuditLog.record!(
        user: current_user,
        action: "permission.denied.works.module",
        auditable: current_user,
        metadata: { path: request.path, method: request.request_method },
        ip_address: request.remote_ip,
        user_agent: request.user_agent
      )
      redirect_to "/backoffice", alert: "No tienes permisos para acceder a Trabajos Masonicos."
    end

    def parse_date(raw)
      return if raw.blank?
      Date.parse(raw.to_s)
    rescue Date::Error
      nil
    end

    def load_productivity_dashboard
      range = @period_from.beginning_of_day..@period_to.end_of_day
      pending_statuses = %w[assigned draft in_review]
      @productivity_pending = MasonicWork.where(created_at: range, status: pending_statuses).count
      @productivity_approved = MasonicWork.where(updated_at: range, status: "approved").count
      @productivity_presented = MasonicWork.where(updated_at: range, status: "presented").count
      @productivity_overdue = MasonicWork.where("due_on < ?", Date.current).where.not(status: %w[presented archived]).count
    end

    def build_monthly_productivity_series
      start_month = Date.current.beginning_of_month - 11.months
      @monthly_productivity_series = (0..11).map do |idx|
        month_start = start_month + idx.months
        month_end = month_start.end_of_month
        {
          label: I18n.l(month_start, format: "%b %Y"),
          created: MasonicWork.where(created_at: month_start.beginning_of_day..month_end.end_of_day).count,
          approved: MasonicWork.where(status: "approved", updated_at: month_start.beginning_of_day..month_end.end_of_day).count,
          presented: MasonicWork.where(status: "presented", updated_at: month_start.beginning_of_day..month_end.end_of_day).count
        }
      end
      @monthly_productivity_max = @monthly_productivity_series.map { |row| [row[:created], row[:approved], row[:presented]].max }.max.to_i
      @monthly_productivity_max = 1 if @monthly_productivity_max.zero?
    end

    def load_works_for_export
      @works_for_export = MasonicWork.includes(:brother, :reviewer_user).order(created_at: :desc)
      @works_for_export = @works_for_export.where(status: params[:status]) if params[:status].present?
      @works_for_export = @works_for_export.where(brother_id: params[:brother_id]) if params[:brother_id].present?
      if params[:q].present?
        pattern = "%#{params[:q].to_s.strip.downcase}%"
        @works_for_export = @works_for_export.where("LOWER(title) LIKE :q OR LOWER(topic) LIKE :q", q: pattern)
      end
      from = parse_date(params[:period_from])
      to = parse_date(params[:period_to])
      if from.present? && to.present?
        @works_for_export = @works_for_export.where(created_at: from.beginning_of_day..to.end_of_day)
      end
    end

    def load_reviews_for_export
      @reviews_for_export = WorkReview.includes(:reviewer_user, :masonic_work).order(reviewed_on: :desc, created_at: :desc)
      if params[:status].present?
        @reviews_for_export = @reviews_for_export.joins(:masonic_work).where(masonic_works: { status: params[:status] })
      end
      @reviews_for_export = @reviews_for_export.where(reviewer_user_id: params[:reviewer_user_id]) if params[:reviewer_user_id].present?
      from = parse_date(params[:period_from])
      to = parse_date(params[:period_to])
      if from.present? && to.present?
        @reviews_for_export = @reviews_for_export.where(reviewed_on: from..to)
      end
    end
  end
end
