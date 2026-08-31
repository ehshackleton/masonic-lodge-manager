module Backoffice
  class TenidasController < ApplicationController
    before_action :require_authentication
    before_action :require_current_lodge!
    before_action :set_tenida, only: %i[show edit update destroy mark_held cancel mark_cited sync_calendar]
    before_action :authorize_secretariat_read!
    before_action :authorize_secretariat_write!, only: %i[new create edit update destroy mark_held cancel mark_cited sync_calendar]
    before_action :load_form_options, only: %i[new edit create update]

    def index
      @status = params[:status].to_s.strip
      @tenidas = tenidas_scope.ordered.includes(:degree, :presiding_brother)
      @tenidas = @tenidas.where(status: @status) if @status.present?
    end

    def show
      @minutes = @tenida.minutes.ordered
      @titular_offices = current_titular_assignments_for(@tenida.held_on)
    end

    def new
      @tenida = tenidas_scope.new(
        held_on: Date.current,
        status: "planned",
        tenida_type: "regular",
        lodge: current_lodge
      )
    end

    def create
      @tenida = tenidas_scope.new(tenida_params)
      @tenida.lodge = current_lodge
      if @tenida.save
        AuditLog.record!(
          user: current_user,
          action: "tenida.create",
          auditable: @tenida,
          metadata: { code: @tenida.code, held_on: @tenida.held_on.to_s, status: @tenida.status },
          ip_address: request.remote_ip,
          user_agent: request.user_agent
        )
        enqueue_calendar_sync
        redirect_to backoffice_tenida_path(@tenida), notice: "Tenida registrada."
      else
        load_form_options
        render :new, status: :unprocessable_entity
      end
    end

    def edit; end

    def update
      if @tenida.update(tenida_params)
        AuditLog.record!(
          user: current_user,
          action: "tenida.update",
          auditable: @tenida,
          metadata: { code: @tenida.code, status: @tenida.status },
          ip_address: request.remote_ip,
          user_agent: request.user_agent
        )
        enqueue_calendar_sync
        redirect_to backoffice_tenida_path(@tenida), notice: "Tenida actualizada."
      else
        load_form_options
        render :edit, status: :unprocessable_entity
      end
    end

    def destroy
      AuditLog.record!(
        user: current_user,
        action: "tenida.destroy",
        auditable: @tenida,
        metadata: { code: @tenida.code },
        ip_address: request.remote_ip,
        user_agent: request.user_agent
      )
      @tenida.destroy
      redirect_to backoffice_tenidas_path, notice: "Tenida eliminada."
    end

    def mark_cited
      @tenida.update!(status: "cited")
      enqueue_calendar_sync
      redirect_to backoffice_tenida_path(@tenida), notice: "Tenida marcada como citada."
    end

    def mark_held
      return redirect_to(backoffice_tenida_path(@tenida), alert: "Transicion no permitida.") unless @tenida.can_mark_held?

      @tenida.update!(status: "held")
      enqueue_calendar_sync
      redirect_to backoffice_tenida_path(@tenida), notice: "Tenida marcada como realizada."
    end

    def cancel
      return redirect_to(backoffice_tenida_path(@tenida), alert: "No se puede cancelar.") unless @tenida.can_cancel?

      @tenida.update!(status: "cancelled")
      enqueue_calendar_sync
      redirect_to backoffice_tenida_path(@tenida), notice: "Tenida cancelada."
    end

    def sync_calendar
      enqueue_calendar_sync(force_now: true)
      redirect_to backoffice_tenida_path(@tenida), notice: "Sincronizacion Calendar encolada/ejecutada."
    end

    private

    def tenidas_scope
      Tenida.for_lodge(current_lodge)
    end

    def set_tenida
      @tenida = tenidas_scope.find(params[:id])
    end

    def load_form_options
      @degrees = Degree.order(rank_order: :asc)
      @brothers = Brother.where(lodge_id: current_lodge.id, active: true).ordered
    end

    def tenida_params
      params.require(:tenida).permit(
        :held_on, :tenida_type, :status, :place, :starts_at, :degree_id,
        :presiding_brother_id, :presiding_capacity, :notes, :code
      )
    end

    # Cargos vigentes en la fecha de la Tenida (titulares del período), distintos de quien preside.
    def current_titular_assignments_for(on_date)
      BrotherOfficeAssignment
        .joins(:brother, :office)
        .where(brothers: { lodge_id: current_lodge.id })
        .where("start_date IS NULL OR start_date <= ?", on_date)
        .where("end_date IS NULL OR end_date >= ?", on_date)
        .includes(:brother, :office)
        .order("offices.name ASC")
    end

    def authorize_secretariat_read!
      return if current_user&.can_access_module?(:secretariat)

      deny!("secretariat_read")
    end

    def authorize_secretariat_write!
      return if current_user&.can_manage_secretariat_action?(:minute_write) ||
                current_user&.has_role?(:secretario) ||
                current_user&.has_role?(:secretariat_manager) ||
                current_user&.has_role?(:superadmin)

      deny!("tenida_write")
    end

    def deny!(denied_action)
      AuditLog.record!(
        user: current_user,
        action: "permission.denied.secretariat.tenida",
        auditable: @tenida || current_user,
        metadata: { denied_action: denied_action, path: request.path },
        ip_address: request.remote_ip,
        user_agent: request.user_agent
      )
      redirect_to "/backoffice/secretaria", alert: "No tienes permisos para esta accion de Tenidas."
    end

    def enqueue_calendar_sync(force_now: false)
      return unless WorkspaceConnection.google.exists?(lodge: current_lodge, status: "connected")

      if force_now
        WorkspaceSyncTenidaCalendarJob.perform_now(@tenida.id)
      else
        WorkspaceSyncTenidaCalendarJob.perform_later(@tenida.id)
      end
    rescue StandardError => e
      Rails.logger.warn("[TenidasController] calendar sync: #{e.message}")
    end
  end
end
