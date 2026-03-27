module Backoffice
  class HospitalController < ApplicationController
    before_action :require_authentication
    before_action :authorize_hospital_read_access!
    before_action :authorize_hospital_operation_access!, only: %i[update_settings generate_monthly_contributions create_contribution create_adjustment pay_death_benefit]
    before_action :authorize_hospital_export_access!, only: %i[export_excel export_pdf export_coverage_excel export_coverage_pdf]
    before_action :set_lodge
    before_action :set_hospital_setting

    def index
      load_hospital_data
    end

    def update_settings
      if @hospital_setting.update(hospital_setting_params)
        redirect_to "/backoffice/hospitalario", notice: "Configuracion del saco hospitalario actualizada."
      else
        redirect_to "/backoffice/hospitalario", alert: @hospital_setting.errors.full_messages.to_sentence
      end
    end

    def create_contribution
      transaction = HospitalFundTransaction.new(base_transaction_params.merge(
        lodge: @lodge,
        entry_type: "income",
        category: "contribution",
        recorded_by_user: current_user
      ))

      persist_transaction(transaction, success_notice: "Aporte hospitalario registrado.")
    end

    def generate_monthly_contributions
      period_date = safe_date(params[:period]) || Date.current
      year = period_date.year
      month = period_date.month
      occurred_on = Date.new(year, month, 1)
      amount = @hospital_setting.contribution_amount

      if amount.to_d <= 0
        redirect_to "/backoffice/hospitalario", alert: "Define un aporte hospitalario mayor a cero en la configuracion."
        return
      end

      created = 0
      skipped = 0

      Brother.where(active: true, membership_status: "active").find_each do |brother|
        reference = monthly_contribution_reference(year, month, brother.id)
        if HospitalFundTransaction.exists?(lodge_id: @lodge.id, reference: reference)
          skipped += 1
          next
        end

        HospitalFundTransaction.create!(
          lodge: @lodge,
          brother: brother,
          recorded_by_user: current_user,
          occurred_on: occurred_on,
          amount: amount,
          entry_type: "income",
          category: "contribution",
          reference: reference,
          notes: "Aporte hospitalario mensual generado automaticamente para #{format('%02d', month)}/#{year}."
        )
        created += 1
      end

      AuditLog.record!(
        user: current_user,
        action: "hospital.monthly_contributions.generate",
        auditable: @lodge,
        metadata: {
          period_year: year,
          period_month: month,
          amount: amount.to_s,
          created_count: created,
          skipped_count: skipped
        },
        ip_address: request.remote_ip,
        user_agent: request.user_agent
      )

      redirect_to "/backoffice/hospitalario", notice: "Generacion masiva completada para #{format('%02d', month)}/#{year}: #{created} creados, #{skipped} omitidos por existir."
    end

    def create_adjustment
      entry_type = params[:entry_type].to_s == "expense" ? "expense" : "income"
      transaction = HospitalFundTransaction.new(base_transaction_params.merge(
        lodge: @lodge,
        entry_type: entry_type,
        category: "adjustment",
        recorded_by_user: current_user
      ))

      persist_transaction(transaction, success_notice: "Ajuste del fondo registrado.")
    end

    def pay_death_benefit
      brother = Brother.find_by(id: params[:brother_id])
      unless brother&.membership_status_deceased?
        redirect_to "/backoffice/hospitalario", alert: "Solo se puede pagar fondo de defuncion a hermanos en estado fallecido."
        return
      end

      transaction = HospitalFundTransaction.new(
        lodge: @lodge,
        brother: brother,
        recorded_by_user: current_user,
        occurred_on: safe_date(params[:occurred_on]) || Date.current,
        amount: parse_decimal(params[:amount]) || @hospital_setting.death_benefit_amount,
        entry_type: "expense",
        category: "death_benefit",
        reference: params[:reference],
        notes: params[:notes].presence || "Pago de fondo de defuncion por pase a Oriente Eterno."
      )
      persist_transaction(transaction, success_notice: "Pago de fondo de defuncion registrado para #{brother.full_name}.")
    end

    def export_excel
      load_hospital_data
      rows = []
      rows << %(<Row><Cell><Data ss:Type="String">Fecha</Data></Cell><Cell><Data ss:Type="String">Tipo</Data></Cell><Cell><Data ss:Type="String">Categoria</Data></Cell><Cell><Data ss:Type="String">Hermano</Data></Cell><Cell><Data ss:Type="String">Monto</Data></Cell><Cell><Data ss:Type="String">Referencia</Data></Cell></Row>)
      @transactions.each do |tx|
        rows << %(<Row><Cell><Data ss:Type="String">#{ERB::Util.h(tx.occurred_on.to_s)}</Data></Cell><Cell><Data ss:Type="String">#{ERB::Util.h(tx.entry_type.humanize)}</Data></Cell><Cell><Data ss:Type="String">#{ERB::Util.h(tx.category.humanize)}</Data></Cell><Cell><Data ss:Type="String">#{ERB::Util.h(tx.brother&.full_name.to_s)}</Data></Cell><Cell><Data ss:Type="String">#{ERB::Util.h(format_currency(tx.amount))}</Data></Cell><Cell><Data ss:Type="String">#{ERB::Util.h(tx.reference.to_s)}</Data></Cell></Row>)
      end
      xml = <<~XML
        <?xml version="1.0"?>
        <?mso-application progid="Excel.Sheet"?>
        <Workbook xmlns="urn:schemas-microsoft-com:office:spreadsheet"
          xmlns:o="urn:schemas-microsoft-com:office:office"
          xmlns:x="urn:schemas-microsoft-com:office:excel"
          xmlns:ss="urn:schemas-microsoft-com:office:spreadsheet">
          <Worksheet ss:Name="Hospitalario">
            <Table>
              #{rows.join("\n")}
            </Table>
          </Worksheet>
        </Workbook>
      XML
      send_data xml, filename: "hospitalario_#{Date.current}.xls", type: "application/vnd.ms-excel"
    end

    def export_pdf
      load_hospital_data
      pdf = Prawn::Document.new(page_size: "A4")
      pdf.text "Saco Hospitalario - Balance y movimientos", size: 16, style: :bold
      pdf.move_down 8
      pdf.text "Balance actual: #{format_currency(@balance)}"
      pdf.text "Total ingresos: #{format_currency(@total_income)}"
      pdf.text "Total egresos: #{format_currency(@total_expense)}"
      pdf.text "Pagos de defuncion: #{@death_benefits_count}"
      pdf.move_down 10
      pdf.text "Movimientos recientes", style: :bold
      @transactions.first(40).each do |tx|
        brother_text = tx.brother&.full_name.presence || "-"
        pdf.text "#{tx.occurred_on} | #{tx.entry_type.humanize} | #{tx.category.humanize} | #{brother_text} | #{format_currency(tx.amount)}"
      end
      pdf.text "Sin movimientos." if @transactions.empty?

      send_data pdf.render, filename: "hospitalario_#{Date.current}.pdf", type: "application/pdf", disposition: "attachment"
    end

    def export_coverage_excel
      load_hospital_data
      rows = []
      rows << %(<Row><Cell><Data ss:Type="String">Mes cobertura</Data></Cell><Cell><Data ss:Type="String">#{ERB::Util.h(@coverage_month.strftime('%m/%Y'))}</Data></Cell></Row>)
      rows << %(<Row><Cell><Data ss:Type="String">Activos</Data></Cell><Cell><Data ss:Type="String">#{ERB::Util.h(@coverage_total_active.to_s)}</Data></Cell></Row>)
      rows << %(<Row><Cell><Data ss:Type="String">Aportaron</Data></Cell><Cell><Data ss:Type="String">#{ERB::Util.h(@coverage_contributed_count.to_s)}</Data></Cell></Row>)
      rows << %(<Row><Cell><Data ss:Type="String">Pendientes</Data></Cell><Cell><Data ss:Type="String">#{ERB::Util.h(@coverage_pending_count.to_s)}</Data></Cell></Row>)
      rows << %(<Row><Cell><Data ss:Type="String">Cobertura %</Data></Cell><Cell><Data ss:Type="String">#{ERB::Util.h(@coverage_percentage.to_s)}</Data></Cell></Row>)
      rows << %(<Row><Cell><Data ss:Type="String"></Data></Cell></Row>)
      rows << %(<Row><Cell><Data ss:Type="String">Hermano</Data></Cell><Cell><Data ss:Type="String">Registro</Data></Cell><Cell><Data ss:Type="String">Estado</Data></Cell><Cell><Data ss:Type="String">Monto aportado</Data></Cell></Row>)
      @coverage_rows.each do |row|
        rows << %(<Row><Cell><Data ss:Type="String">#{ERB::Util.h(row[:brother].full_name)}</Data></Cell><Cell><Data ss:Type="String">#{ERB::Util.h(row[:brother].registry_number.to_s)}</Data></Cell><Cell><Data ss:Type="String">#{ERB::Util.h(row[:contributed] ? 'Aporto' : 'Pendiente')}</Data></Cell><Cell><Data ss:Type="String">#{ERB::Util.h(format_currency(row[:contributed_amount]))}</Data></Cell></Row>)
      end
      xml = <<~XML
        <?xml version="1.0"?>
        <?mso-application progid="Excel.Sheet"?>
        <Workbook xmlns="urn:schemas-microsoft-com:office:spreadsheet"
          xmlns:o="urn:schemas-microsoft-com:office:office"
          xmlns:x="urn:schemas-microsoft-com:office:excel"
          xmlns:ss="urn:schemas-microsoft-com:office:spreadsheet">
          <Worksheet ss:Name="Cobertura">
            <Table>
              #{rows.join("\n")}
            </Table>
          </Worksheet>
        </Workbook>
      XML
      send_data xml, filename: "hospitalario_cobertura_#{@coverage_month.strftime('%Y_%m')}.xls", type: "application/vnd.ms-excel"
    end

    def export_coverage_pdf
      load_hospital_data
      pdf = Prawn::Document.new(page_size: "A4")
      pdf.text "Reporte de cobertura mensual - Saco Hospitalario", size: 16, style: :bold
      pdf.move_down 8
      pdf.text "Mes: #{@coverage_month.strftime('%m/%Y')}"
      pdf.text "Activos: #{@coverage_total_active}"
      pdf.text "Aportaron: #{@coverage_contributed_count}"
      pdf.text "Pendientes: #{@coverage_pending_count}"
      pdf.text "Cobertura: #{@coverage_percentage}%"
      pdf.move_down 10
      pdf.text "Detalle por hermano", style: :bold
      @coverage_rows.each do |row|
        status = row[:contributed] ? "Aporto" : "Pendiente"
        pdf.text "#{row[:brother].full_name} (#{row[:brother].registry_number}) | #{status} | #{format_currency(row[:contributed_amount])}", size: 10
      end
      pdf.text "Sin hermanos activos para reporte." if @coverage_rows.empty?
      send_data pdf.render, filename: "hospitalario_cobertura_#{@coverage_month.strftime('%Y_%m')}.pdf", type: "application/pdf", disposition: "attachment"
    end

    private

    def set_lodge
      @lodge = Lodge.first
    end

    def set_hospital_setting
      @hospital_setting = HospitalFundSetting.find_or_create_by!(lodge: @lodge) do |setting|
        setting.contribution_amount = 3000
        setting.death_benefit_amount = 300000
        setting.currency = "CLP"
        setting.active = true
      end
    end

    def load_hospital_data
      @from = safe_date(params[:from]) || Date.current.beginning_of_month
      @to = safe_date(params[:to]) || Date.current.end_of_month
      @transactions = @lodge.hospital_fund_transactions.includes(:brother, :recorded_by_user).where(occurred_on: @from..@to).order(occurred_on: :desc, created_at: :desc)
      @total_income = @transactions.where(entry_type: "income").sum(:amount)
      @total_expense = @transactions.where(entry_type: "expense").sum(:amount)
      @balance = @lodge.hospital_fund_transactions.where(entry_type: "income").sum(:amount) - @lodge.hospital_fund_transactions.where(entry_type: "expense").sum(:amount)
      @death_benefits_count = @transactions.where(category: "death_benefit").count
      @deceased_brothers = Brother.where(membership_status: "deceased").ordered
      build_monthly_coverage_report
    end

    def hospital_setting_params
      params.require(:hospital_fund_setting).permit(:contribution_amount, :death_benefit_amount, :currency, :active)
    end

    def base_transaction_params
      {
        occurred_on: safe_date(params[:occurred_on]) || Date.current,
        amount: parse_decimal(params[:amount]),
        reference: params[:reference],
        notes: params[:notes]
      }
    end

    def persist_transaction(transaction, success_notice:)
      if transaction.save
        AuditLog.record!(
          user: current_user,
          action: "hospital.transaction.create",
          auditable: transaction,
          metadata: {
            entry_type: transaction.entry_type,
            category: transaction.category,
            amount: transaction.amount.to_s
          },
          ip_address: request.remote_ip,
          user_agent: request.user_agent
        )
        redirect_to "/backoffice/hospitalario", notice: success_notice
      else
        redirect_to "/backoffice/hospitalario", alert: transaction.errors.full_messages.to_sentence
      end
    end

    def parse_decimal(raw)
      return nil if raw.blank?
      BigDecimal(raw.to_s)
    rescue ArgumentError
      nil
    end

    def safe_date(raw)
      return nil if raw.blank?
      Date.parse(raw.to_s)
    rescue ArgumentError
      nil
    end

    def format_currency(value)
      ActionController::Base.helpers.number_to_currency(value, unit: "$", precision: 0)
    end

    def monthly_contribution_reference(year, month, brother_id)
      "HOSP-CONTRIB-#{year}#{format('%02d', month)}-B#{brother_id}"
    end

    def build_monthly_coverage_report
      coverage_date = safe_date(params[:coverage_period]) || Date.current
      @coverage_month = coverage_date.beginning_of_month
      @coverage_filter = params[:coverage_filter].to_s.presence || "all"
      month_range = @coverage_month.beginning_of_month..@coverage_month.end_of_month
      active_brothers = Brother.where(active: true, membership_status: "active").ordered
      contribution_sums = @lodge.hospital_fund_transactions
                              .where(category: "contribution", entry_type: "income", occurred_on: month_range)
                              .where.not(brother_id: nil)
                              .group(:brother_id)
                              .sum(:amount)

      all_rows = active_brothers.map do |brother|
        contributed_amount = contribution_sums[brother.id].to_d
        has_contributed = contributed_amount.positive?
        {
          brother: brother,
          contributed: has_contributed,
          contributed_amount: contributed_amount
        }
      end

      @coverage_total_active = all_rows.size
      @coverage_contributed_count = all_rows.count { |row| row[:contributed] }
      @coverage_pending_count = @coverage_total_active - @coverage_contributed_count
      @coverage_percentage = if @coverage_total_active.positive?
                               ((@coverage_contributed_count.to_f / @coverage_total_active) * 100).round(1)
                             else
                               0
                             end

      @coverage_rows = case @coverage_filter
                       when "contributed"
                         all_rows.select { |row| row[:contributed] }
                       when "pending"
                         all_rows.reject { |row| row[:contributed] }
                       else
                         all_rows
                       end
    end

    def authorize_hospital_read_access!
      return if current_user&.can_access_module?(:hospital) && current_user&.can_manage_hospital_action?(:read)

      audit_permission_denied("hospital_read")
      redirect_to "/backoffice", alert: "No tienes permisos para acceder al modulo Hospitalario."
    end

    def authorize_hospital_operation_access!
      return if current_user&.can_manage_hospital_action?(:operate)

      audit_permission_denied("hospital_operate")
      redirect_to "/backoffice/hospitalario", alert: "No tienes permisos para registrar operaciones del saco hospitalario."
    end

    def authorize_hospital_export_access!
      return if current_user&.can_manage_hospital_action?(:export)

      audit_permission_denied("hospital_export")
      redirect_to "/backoffice/hospitalario", alert: "No tienes permisos para exportar reportes hospitalarios."
    end

    def audit_permission_denied(denied_action)
      AuditLog.record!(
        user: current_user,
        action: "permission.denied.hospital",
        auditable: current_user,
        metadata: { denied_action: denied_action, path: request.path, method: request.request_method },
        ip_address: request.remote_ip,
        user_agent: request.user_agent
      )
    end
  end
end
