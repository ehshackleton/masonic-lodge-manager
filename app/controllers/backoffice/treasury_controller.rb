module Backoffice
  class TreasuryController < ApplicationController
    before_action :require_authentication
    before_action :authorize_treasury_read_access!
    before_action :authorize_treasury_operation_access!, only: %i[update_settings generate_charges create_payment]
    before_action :authorize_treasury_closure_access!, only: %i[create_closure destroy_closure]
    before_action :authorize_treasury_export_access!, only: %i[export_excel export_pdf export_delinquency_excel export_delinquency_pdf]
    before_action :set_lodge
    before_action :set_treasury_setting

    def index
      prepare_dashboard_data
    end

    def update_settings
      if @treasury_setting.update(settings_params)
        redirect_to "/backoffice/tesoreria", notice: "Configuracion de tesoreria actualizada."
      else
        redirect_to "/backoffice/tesoreria", alert: @treasury_setting.errors.full_messages.to_sentence
      end
    end

    def generate_charges
      target_date = safe_date(params[:period]) || Date.current
      year = target_date.year
      month = target_date.month
      if period_closed?(year, month)
        redirect_to "/backoffice/tesoreria", alert: "Periodo #{format('%02d', month)}/#{year} cerrado. No se pueden generar cargos."
        return
      end
      due_on = Date.new(year, month, [@treasury_setting.due_day, 28].min)

      created = 0
      Brother.where(active: true, membership_status: "active").find_each do |brother|
        next if Charge.exists?(brother_id: brother.id, period_year: year, period_month: month)

        Charge.create!(
          brother: brother,
          period_year: year,
          period_month: month,
          amount: @treasury_setting.monthly_fee,
          due_on: due_on,
          status: "pending",
          notes: "Cuota mensual generada automaticamente"
        )
        create_ledger_entry_for_charge(brother, year, month)
        created += 1
      end

      redirect_to "/backoffice/tesoreria", notice: "Generacion completada: #{created} cargos creados para #{format('%02d', month)}/#{year}."
    end

    def create_payment
      payment = Payment.new(payment_params)
      payment_date = payment.paid_on || Date.current
      if period_closed?(payment_date.year, payment_date.month)
        redirect_to "/backoffice/tesoreria", alert: "Periodo #{format('%02d', payment_date.month)}/#{payment_date.year} cerrado. No se puede registrar pago."
        return
      end
      payment.currency = @treasury_setting.currency if payment.currency.blank?
      payment.received_by_user = current_user

      if payment.save
        apply_payment_to_charges(payment)
        create_ledger_entry_for_payment(payment)
        redirect_to "/backoffice/tesoreria", notice: "Pago registrado correctamente."
      else
        redirect_to "/backoffice/tesoreria", alert: payment.errors.full_messages.to_sentence
      end
    end

    def create_closure
      target = safe_date(params[:period]) || Date.current
      closure = @lodge.monthly_closures.new(
        period_year: target.year,
        period_month: target.month,
        closed_at: Time.current,
        closed_by_user: current_user,
        notes: params[:notes]
      )

      if closure.save
        redirect_to "/backoffice/tesoreria", notice: "Periodo #{format('%02d', target.month)}/#{target.year} cerrado."
      else
        redirect_to "/backoffice/tesoreria", alert: closure.errors.full_messages.to_sentence
      end
    end

    def destroy_closure
      closure = @lodge.monthly_closures.find(params[:id])
      period = format("%02d/%<y>d", closure.period_month, y: closure.period_year)
      closure.destroy
      redirect_to "/backoffice/tesoreria", notice: "Cierre #{period} reabierto."
    end

    def export_excel
      prepare_dashboard_data
      send_data(
        build_excel_xml,
        filename: "tesoreria_ingresos_#{Date.current}.xls",
        type: "application/vnd.ms-excel"
      )
    end

    def export_pdf
      prepare_dashboard_data
      pdf = Prawn::Document.new(page_size: "A4")
      pdf.text "Tesoreria y contabilidad - Tablero de ingresos", size: 16, style: :bold
      pdf.move_down 8
      pdf.text "Rango: #{@from} a #{@to}"
      pdf.text "Ingresos: #{format_currency(@total_income)}"
      pdf.text "Pagos registrados: #{@payments_count}"
      pdf.text "Esperado mensual: #{format_currency(@expected_month_income)}"
      pdf.text "Recaudado mes actual: #{format_currency(@collected_month_income)}"
      pdf.text "Cuotas vencidas: #{@overdue_count}"
      pdf.move_down 12
      pdf.text "Morosidad por hermano", style: :bold
      @delinquency_rows.first(25).each do |row|
        pdf.text "- #{row[:brother].full_name}: saldo #{format_currency(row[:balance])}, antiguedad #{row[:aging_days]} dias"
      end

      send_data pdf.render, filename: "tesoreria_ingresos_#{Date.current}.pdf", type: "application/pdf", disposition: "attachment"
    end

    def export_delinquency_excel
      prepare_dashboard_data
      rows = []
      rows << %(<Row><Cell><Data ss:Type="String">Hermano</Data></Cell><Cell><Data ss:Type="String">Registro</Data></Cell><Cell><Data ss:Type="String">Saldo pendiente</Data></Cell><Cell><Data ss:Type="String">Primera cuota vencida</Data></Cell><Cell><Data ss:Type="String">Antiguedad (dias)</Data></Cell></Row>)
      @delinquency_rows.each do |row|
        rows << %(<Row><Cell><Data ss:Type="String">#{ERB::Util.h(row[:brother].full_name)}</Data></Cell><Cell><Data ss:Type="String">#{ERB::Util.h(row[:brother].registry_number.to_s)}</Data></Cell><Cell><Data ss:Type="String">#{ERB::Util.h(format_currency(row[:balance]))}</Data></Cell><Cell><Data ss:Type="String">#{ERB::Util.h(row[:oldest_due_on].to_s)}</Data></Cell><Cell><Data ss:Type="String">#{ERB::Util.h(row[:aging_days].to_s)}</Data></Cell></Row>)
      end
      xml = <<~XML
        <?xml version="1.0"?>
        <?mso-application progid="Excel.Sheet"?>
        <Workbook xmlns="urn:schemas-microsoft-com:office:spreadsheet"
          xmlns:o="urn:schemas-microsoft-com:office:office"
          xmlns:x="urn:schemas-microsoft-com:office:excel"
          xmlns:ss="urn:schemas-microsoft-com:office:spreadsheet">
          <Worksheet ss:Name="Morosidad">
            <Table>
              #{rows.join("\n")}
            </Table>
          </Worksheet>
        </Workbook>
      XML
      send_data xml, filename: "morosidad_#{Date.current}.xls", type: "application/vnd.ms-excel"
    end

    def export_delinquency_pdf
      prepare_dashboard_data
      pdf = Prawn::Document.new(page_size: "A4")
      pdf.text "Reporte de morosidad por hermano", size: 16, style: :bold
      pdf.move_down 8
      pdf.text "Fecha de emision: #{Date.current}"
      pdf.move_down 10
      @delinquency_rows.each do |row|
        pdf.text "#{row[:brother].full_name} (#{row[:brother].registry_number})"
        pdf.text "Saldo: #{format_currency(row[:balance])} | Vencida desde: #{row[:oldest_due_on]} | Antiguedad: #{row[:aging_days]} dias", size: 10
        pdf.move_down 4
      end
      pdf.text "Sin morosidad registrada." if @delinquency_rows.empty?
      send_data pdf.render, filename: "morosidad_#{Date.current}.pdf", type: "application/pdf", disposition: "attachment"
    end

    private

    def set_lodge
      @lodge = Lodge.first
    end

    def set_treasury_setting
      @treasury_setting = TreasurySetting.find_or_create_by!(lodge: @lodge) do |setting|
        setting.monthly_fee = 15000
        setting.currency = "CLP"
        setting.due_day = 10
      end
    end

    def settings_params
      params.require(:treasury_setting).permit(:monthly_fee, :currency, :due_day, :active)
    end

    def payment_params
      params.require(:payment).permit(:brother_id, :paid_on, :amount, :currency, :payment_method, :reference, :notes)
    end

    def safe_date(raw)
      return nil if raw.blank?

      Date.parse(raw)
    rescue ArgumentError
      nil
    end

    def monthly_charges(year, month)
      Charge.where(period_year: year, period_month: month)
    end

    def monthly_collected_amount(year, month)
      from = Date.new(year, month, 1)
      to = from.end_of_month
      Payment.where(paid_on: from..to).sum(:amount)
    end

    def apply_payment_to_charges(payment)
      remaining = payment.amount.to_d
      charges = payment.brother.charges.where(status: %w[pending partial]).order(period_year: :asc, period_month: :asc)

      charges.each do |charge|
        break if remaining <= 0

        paid_for_charge = charge.payment_allocations.sum(:applied_amount)
        balance = charge.amount - paid_for_charge
        next if balance <= 0

        applied = [remaining, balance].min
        remaining -= applied

        PaymentAllocation.create!(payment: payment, charge: charge, applied_amount: applied)

        new_paid_total = paid_for_charge + applied
        new_status = if new_paid_total >= charge.amount
                       "paid"
                     else
                       "partial"
                     end
        charge.update!(status: new_status)
      end
    end

    def period_closed?(year, month)
      @lodge.monthly_closures.exists?(period_year: year, period_month: month)
    end

    def build_delinquency_rows
      Brother.includes(:charges).where(active: true).map do |brother|
        debt_charges = brother.charges.where(status: %w[pending partial])
        next if debt_charges.empty?

        balance = debt_charges.to_a.sum { |charge| charge.pending_amount.to_d }
        next if balance <= 0

        oldest_due = debt_charges.minimum(:due_on)
        aging = oldest_due.present? ? (Date.current - oldest_due).to_i : 0
        {
          brother: brother,
          balance: balance,
          oldest_due_on: oldest_due,
          aging_days: [aging, 0].max
        }
      end.compact.sort_by { |row| [-row[:balance].to_f, -row[:aging_days]] }
    end

    def prepare_dashboard_data
      @from = safe_date(params[:from]) || Date.current.beginning_of_month
      @to = safe_date(params[:to]) || Date.current.end_of_month
      @payments = Payment.includes(:brother).where(paid_on: @from..@to).order(paid_on: :desc, created_at: :desc)
      @active_brothers = Brother.where(active: true, membership_status: "active")
      @total_income = @payments.sum(:amount)
      @payments_count = @payments.count
      @expected_month_income = @active_brothers.count * @treasury_setting.monthly_fee
      @collected_month_income = monthly_collected_amount(Date.current.year, Date.current.month)
      @charges = monthly_charges(Date.current.year, Date.current.month)
      @overdue_count = @charges.where(status: %w[pending partial]).where("due_on < ?", Date.current).count
      @delinquency_rows = build_delinquency_rows
      @new_payment = Payment.new(paid_on: Date.current, currency: @treasury_setting.currency)
      @closures = @lodge.monthly_closures.order(period_year: :desc, period_month: :desc)
      @monthly_income_series = build_monthly_income_series
      @ledger_entries = @lodge.ledger_entries.where(occurred_on: @from..@to).order(occurred_on: :desc, created_at: :desc).limit(150)
    end

    def format_currency(value)
      ActionController::Base.helpers.number_to_currency(value, unit: "$", precision: 0)
    end

    def build_excel_xml
      rows = []
      rows << %(<Row><Cell><Data ss:Type="String">Indicador</Data></Cell><Cell><Data ss:Type="String">Valor</Data></Cell></Row>)
      rows << excel_row("Rango", "#{@from} a #{@to}")
      rows << excel_row("Ingresos", format_currency(@total_income))
      rows << excel_row("Pagos registrados", @payments_count.to_s)
      rows << excel_row("Esperado mensual", format_currency(@expected_month_income))
      rows << excel_row("Recaudado mes actual", format_currency(@collected_month_income))
      rows << excel_row("Cuotas vencidas", @overdue_count.to_s)
      rows << %(<Row><Cell><Data ss:Type="String"></Data></Cell></Row>)
      rows << %(<Row><Cell><Data ss:Type="String">Morosidad por hermano</Data></Cell></Row>)
      @delinquency_rows.each do |row|
        rows << excel_row("#{row[:brother].full_name} (#{row[:brother].registry_number})", "#{format_currency(row[:balance])} - #{row[:aging_days]} dias")
      end

      <<~XML
        <?xml version="1.0"?>
        <?mso-application progid="Excel.Sheet"?>
        <Workbook xmlns="urn:schemas-microsoft-com:office:spreadsheet"
          xmlns:o="urn:schemas-microsoft-com:office:office"
          xmlns:x="urn:schemas-microsoft-com:office:excel"
          xmlns:ss="urn:schemas-microsoft-com:office:spreadsheet">
          <Worksheet ss:Name="Ingresos">
            <Table>
              #{rows.join("\n")}
            </Table>
          </Worksheet>
        </Workbook>
      XML
    end

    def excel_row(left, right)
      %(<Row><Cell><Data ss:Type="String">#{ERB::Util.h(left.to_s)}</Data></Cell><Cell><Data ss:Type="String">#{ERB::Util.h(right.to_s)}</Data></Cell></Row>)
    end

    def build_monthly_income_series
      current = Date.current.beginning_of_month
      (0..11).map do |i|
        month_date = current << (11 - i)
        from = month_date.beginning_of_month
        to = month_date.end_of_month
        amount = Payment.where(paid_on: from..to).sum(:amount)
        { label: month_date.strftime("%m/%y"), amount: amount.to_d }
      end
    end

    def create_ledger_entry_for_charge(brother, year, month)
      charge = brother.charges.find_by(period_year: year, period_month: month)
      return unless charge

      LedgerEntry.create!(
        lodge: @lodge,
        occurred_on: charge.due_on || Date.new(year, month, 1),
        concept: "Cargo cuota mensual #{format('%02d', month)}/#{year}",
        reference_type: "Charge",
        reference_id: charge.id,
        debit_account: "Cuentas por cobrar",
        credit_account: "Ingresos por cuotas",
        amount: charge.amount,
        period_year: year,
        period_month: month
      )
    end

    def create_ledger_entry_for_payment(payment)
      LedgerEntry.create!(
        lodge: @lodge,
        occurred_on: payment.paid_on,
        concept: "Pago de cuota - #{payment.brother.full_name}",
        reference_type: "Payment",
        reference_id: payment.id,
        debit_account: "Caja/Bancos",
        credit_account: "Cuentas por cobrar",
        amount: payment.amount,
        period_year: payment.paid_on.year,
        period_month: payment.paid_on.month
      )
    end

    def authorize_treasury_read_access!
      return if current_user&.can_access_module?(:treasury) && current_user&.can_manage_treasury_action?(:read)

      audit_permission_denied("treasury_read")
      redirect_to "/backoffice", alert: "No tienes permisos para acceder a Tesoreria."
    end

    def authorize_treasury_operation_access!
      return if current_user&.can_manage_treasury_action?(:operate)

      audit_permission_denied("treasury_operate")
      redirect_to "/backoffice/tesoreria", alert: "No tienes permisos para operar en Tesoreria."
    end

    def authorize_treasury_closure_access!
      return if current_user&.can_manage_treasury_action?(:close_period)

      audit_permission_denied("treasury_close_period")
      redirect_to "/backoffice/tesoreria", alert: "No tienes permisos para cierres mensuales."
    end

    def authorize_treasury_export_access!
      return if current_user&.can_manage_treasury_action?(:export)

      audit_permission_denied("treasury_export")
      redirect_to "/backoffice/tesoreria", alert: "No tienes permisos para exportar reportes de Tesoreria."
    end

    def audit_permission_denied(denied_action)
      AuditLog.record!(
        user: current_user,
        action: "permission.denied.treasury",
        auditable: current_user,
        metadata: { denied_action: denied_action, path: request.path, method: request.request_method },
        ip_address: request.remote_ip,
        user_agent: request.user_agent
      )
    end
  end
end
