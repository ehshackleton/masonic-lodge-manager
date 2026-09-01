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

      @masonic_works = works_list_scope
                                  .order(Arel.sql("due_on ASC NULLS LAST, created_at DESC"))

      load_productivity_dashboard
      build_monthly_productivity_series
    end

    def export_excel
      load_works_for_export
      rows = @works_for_export.map do |work|
        %(<Row><Cell><Data ss:Type="String">#{ERB::Util.h(work.title.to_s)}</Data></Cell><Cell><Data ss:Type="String">#{ERB::Util.h(work.brother&.full_name.to_s)}</Data></Cell><Cell><Data ss:Type="String">#{ERB::Util.h(work.status.humanize)}</Data></Cell><Cell><Data ss:Type="String">#{ERB::Util.h(work.assigned_on.to_s)}</Data></Cell><Cell><Data ss:Type="String">#{ERB::Util.h(work.due_on.to_s)}</Data></Cell></Row>)
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
      pdf_bytes = build_works_list_pdf(
        title: "Trabajos masonicos",
        subtitle: "Reporte de trabajos"
      )
      send_data pdf_bytes, filename: "trabajos_masonicos_#{Date.current}.pdf", type: "application/pdf", disposition: "attachment"
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
      pdf_bytes = Pdf::InstitutionalReport.new(
        title: "Revisiones de trabajos",
        subtitle: "Reporte de revisiones",
        lodge: current_lodge,
        meta_lines: [
          "Emitido: #{I18n.l(Date.current, format: :long)}",
          "Registros: #{@reviews_for_export.size}",
          ("Estado trabajo: #{params[:status]}" if params[:status].present?)
        ].compact,
        emitted_by: current_user.full_name
      ).render do |report, pdf|
        if @reviews_for_export.empty?
          report.paragraph(pdf, "Sin revisiones para exportar.", muted: true)
        else
          report.table(
            pdf,
            headers: %w[Trabajo Revisor Fecha Estado Comentarios],
            rows: @reviews_for_export.map do |review|
              [
                review.masonic_work&.title,
                review.reviewer_user&.email,
                review.reviewed_on,
                review.status.humanize,
                review.comments.presence || "-"
              ]
            end,
            widths: [ 2.2, 1.5, 0.9, 0.9, 2.0 ]
          )
        end
      end

      send_data pdf_bytes, filename: "revisiones_trabajos_#{Date.current}.pdf", type: "application/pdf", disposition: "attachment"
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

      brother_label = @brother_id.present? ? Brother.find_by(id: @brother_id)&.full_name : nil
      pdf_bytes = Pdf::InstitutionalReport.new(
        title: "Tablero de productividad",
        subtitle: "Trabajos masonicos",
        lodge: current_lodge,
        meta_lines: [
          "Periodo: #{@period_from} a #{@period_to}",
          "Estado: #{@status.presence || 'todos'}",
          "Hermano: #{brother_label || 'todos'}",
          "Busqueda: #{@q.presence || '-'}"
        ],
        emitted_by: current_user.full_name
      ).render do |report, pdf|
        report.section(pdf, "Resumen KPI") do
          report.key_values(pdf, [
            [ "Pendientes", @productivity_pending ],
            [ "Aprobados", @productivity_approved ],
            [ "Presentados", @productivity_presented ],
            [ "Vencidos", @productivity_overdue ]
          ])
        end

        report.section(pdf, "Productividad mensual (12 meses)") do
          report.table(
            pdf,
            headers: %w[Mes Creados Aprobados Presentados],
            rows: @monthly_productivity_series.map do |row|
              [ row[:label], row[:created], row[:approved], row[:presented] ]
            end,
            widths: [ 1.4, 0.9, 0.9, 0.9 ]
          )
        end

        report.section(pdf, "Detalle de trabajos") do
          works = @works_for_export.limit(200)
          if works.empty?
            report.paragraph(pdf, "Sin trabajos para detallar.", muted: true)
          else
            report.table(
              pdf,
              headers: %w[Trabajo Hermano Estado Asignacion Compromiso],
              rows: works.map do |work|
                [
                  work.title,
                  work.brother&.full_name,
                  work.status.humanize,
                  work.assigned_on || "-",
                  work.due_on || "-"
                ]
              end,
              widths: [ 2.8, 1.8, 1.0, 1.0, 1.0 ]
            )
          end
        end
      end

      send_data pdf_bytes, filename: "tablero_trabajos_masonicos_#{Date.current}.pdf", type: "application/pdf", disposition: "attachment"
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
      @monthly_productivity_max = @monthly_productivity_series.map { |row| [ row[:created], row[:approved], row[:presented] ].max }.max.to_i
      @monthly_productivity_max = 1 if @monthly_productivity_max.zero?
    end

    def works_list_scope
      scope = MasonicWork.includes(:brother, :degree, :reviewer_user)
      scope = scope.where(status: filter_param(:status)) if filter_param(:status).present?
      scope = scope.where(brother_id: filter_param(:brother_id)) if filter_param(:brother_id).present?

      q = filter_param(:q)
      if q.present?
        pattern = "%#{q.downcase}%"
        scope = scope.where("LOWER(title) LIKE :q OR LOWER(topic) LIKE :q", q: pattern)
      end

      scope
    end

    def filter_param(key)
      params[key].to_s.strip
    end

    def load_works_for_export
      @works_for_export = works_list_scope.order(Arel.sql("due_on ASC NULLS LAST, created_at DESC"))
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

    def build_works_list_pdf(title:, subtitle:)
      Pdf::InstitutionalReport.new(
        title: title,
        subtitle: subtitle,
        lodge: current_lodge,
        meta_lines: [
          "Emitido: #{I18n.l(Date.current, format: :long)}",
          "Registros: #{@works_for_export.size}",
          ("Estado: #{filter_param(:status)}" if filter_param(:status).present?),
          ("Hermano ID: #{filter_param(:brother_id)}" if filter_param(:brother_id).present?),
          ("Busqueda: #{filter_param(:q)}" if filter_param(:q).present?)
        ].compact,
        emitted_by: current_user.full_name
      ).render do |report, pdf|
        if @works_for_export.empty?
          report.paragraph(pdf, "Sin trabajos para exportar.", muted: true)
        else
          report.table(
            pdf,
            headers: %w[Trabajo Hermano Estado Asignacion Compromiso],
            rows: @works_for_export.map do |work|
              [
                work.title,
                work.brother&.full_name,
                work.status.humanize,
                work.assigned_on || "-",
                work.due_on || "-"
              ]
            end,
            widths: [ 2.8, 1.8, 1.0, 1.0, 1.0 ]
          )
        end
      end
    end
  end
end
