# frozen_string_literal: true

module Certificates
  class ActiveMemberPdf
    ACCENT = "C9A227"
    MUTED = "666666"

    def initialize(brother:, issue:, verification_url:, issued_on: Date.current, issued_by: nil)
      @brother = brother
      @lodge = brother.lodge
      @issue = issue
      @verification_url = verification_url
      @issued_on = issued_on
      @issued_by = issued_by
    end

    def render
      PrawnDocument.build(margin: 48) do |pdf|
        draw_page_frame(pdf)
        draw_corner_marks(pdf)
        draw_header(pdf)
        draw_body_panel(pdf)
        draw_signatures(pdf)
        draw_authenticity_mark(pdf)
        draw_footer(pdf)
      end.render
    end

    def self.eligible?(brother)
      brother.membership_status_active? &&
        brother.active? &&
        brother.current_degree.present?
    end

    private

    def draw_page_frame(pdf)
      pdf.canvas do
        pdf.stroke_color ACCENT
        pdf.line_width 2
        inset = 28
        width = pdf.page.dimensions[2] - (inset * 2)
        height = pdf.page.dimensions[3] - (inset * 2)
        pdf.stroke_rectangle [ inset, pdf.page.dimensions[3] - inset ], width, height

        pdf.line_width 0.75
        pdf.stroke_rectangle [ inset + 8, pdf.page.dimensions[3] - inset - 8 ], width - 16, height - 16
      end
    end

    def draw_corner_marks(pdf)
      mark_path = asset_path(:mark)
      return unless mark_path

      pdf.canvas do
        size = 34
        inset = 40
        max_y = pdf.page.dimensions[3] - inset
        max_x = pdf.page.dimensions[2] - inset - size
        pdf.image mark_path, at: [ inset, max_y ], width: size
        pdf.image mark_path, at: [ max_x, max_y ], width: size
        pdf.image mark_path, at: [ inset, inset + size ], width: size
        pdf.image mark_path, at: [ max_x, inset + size ], width: size
      end
    end

    def draw_header(pdf)
      insignia_path = asset_path(:insignia)
      logo_path = asset_path(:logo)
      top = pdf.cursor

      if insignia_path
        pdf.image insignia_path, at: [ 0, top ], width: 58
        pdf.image insignia_path, at: [ pdf.bounds.width - 58, top ], width: 58
      end

      if logo_path
        pdf.image logo_path, at: [ (pdf.bounds.width - 128) / 2, top + 2 ], width: 128
      end

      pdf.move_down 78
      pdf.text @lodge.name.to_s, align: :center, size: 13, style: :bold
      pdf.text lodge_subtitle, align: :center, size: 10, color: MUTED
      pdf.move_down 14
      pdf.stroke_color ACCENT
      pdf.line_width 1
      pdf.stroke_horizontal_rule
      pdf.move_down 14
      pdf.text "CERTIFICADO DE MIEMBRO ACTIVO", align: :center, size: 15, style: :bold
      pdf.move_down 18
    end

    def draw_body_panel(pdf)
      pdf.stroke_color "999999"
      pdf.line_width 0.5
      panel_top = pdf.cursor

      pdf.pad(16) do
        pdf.text certificate_body, align: :justify, leading: 5, size: 11
        pdf.move_down 14
        pdf.text member_details, size: 10, leading: 4
        pdf.move_down 16
        pdf.text issuance_paragraph, align: :justify, size: 10, leading: 4
      end

      panel_height = panel_top - pdf.cursor + 32
      pdf.stroke_rectangle [ 0, panel_top + 16 ], pdf.bounds.width, panel_height
      pdf.move_down 12
    end

    def draw_signatures(pdf)
      pdf.move_down 20
      vm_name = current_office_holder_name("venerable_maestro")
      sec_name = current_office_holder_name("secretario")
      column_width = (pdf.bounds.width - 24) / 2
      top = pdf.cursor

      pdf.bounding_box([ 0, top ], width: column_width) do
        pdf.text signature_line(vm_name), align: :center, style: :bold, size: 10
        pdf.move_down 28
        pdf.stroke_color ACCENT
        pdf.stroke_horizontal_rule
        pdf.move_down 4
        pdf.text "Venerable Maestro", align: :center, size: 10
      end

      pdf.bounding_box([ column_width + 24, top ], width: column_width) do
        pdf.text signature_line(sec_name), align: :center, style: :bold, size: 10
        pdf.move_down 28
        pdf.stroke_color ACCENT
        pdf.stroke_horizontal_rule
        pdf.move_down 4
        pdf.text "Secretario", align: :center, size: 10
      end
    end

    def draw_authenticity_mark(pdf)
      pdf.move_down 24
      pdf.stroke_color ACCENT
      pdf.line_width 1
      pdf.stroke_horizontal_rule
      pdf.move_down 12

      qr_io = qr_code_io(@verification_url)
      top = pdf.cursor

      pdf.image qr_io, at: [ 0, top ], width: 78

      pdf.bounding_box([ 92, top ], width: pdf.bounds.width - 92) do
        pdf.text "Marca digital de autenticidad", style: :bold, size: 10
        pdf.move_down 6
        pdf.text "Folio: #{@issue.folio}", size: 9
        pdf.text "Codigo: #{@issue.verification_code}", size: 9
        pdf.text "Sello digital: #{@issue.digital_seal}", size: 9
        pdf.move_down 4
        pdf.text "Escanee el codigo QR o visite el enlace para verificar este certificado.", size: 8, color: MUTED
        pdf.text @verification_url, size: 7, color: MUTED
      end
    end

    def draw_footer(pdf)
      pdf.move_down 16
      pdf.text "Documento administrativo emitido por Secretaría. No sustituye resoluciones del Taller ni de la Gran Logia.",
               align: :center,
               size: 8,
               color: MUTED
      if @issued_by
        pdf.move_down 4
        pdf.text "Emitido por: #{@issued_by}", align: :center, size: 8, color: MUTED
      end
    end

    def certificate_body
      name = @brother.full_name
      degree = @brother.current_degree.name
      <<~TEXT.squish
        La #{@lodge.name}, del #{@lodge.orient.presence || "Valle de Santiago"},
        adscrita a la #{@lodge.jurisdiction.presence || "Gran Logia Mixta de Chile"},
        certifica que el Q∴H∴ #{name} es miembro activo de esta Respetable Logia,
        encontrándose en grado de #{degree} y en regularidad institucional
        según los registros vigentes de Secretaría a la fecha de emisión.
      TEXT
    end

    def member_details
      lines = []
      lines << "Registro logial: #{@brother.registry_number}"
      lines << "Grado actual: #{@brother.current_degree.name}"
      lines << "Fecha de iniciación: #{format_date(@brother.initiation_date)}" if @brother.initiation_date.present?
      lines << "Nombre simbólico: #{@brother.symbolic_name}" if @brother.symbolic_name.present?
      lines.join("\n")
    end

    def issuance_paragraph
      "El presente documento se expide a solicitud de Secretaría para fines institucionales " \
        "autorizados, en #{@lodge.orient.presence || 'Santiago de Chile'}, " \
        "a #{format_date(@issued_on)}."
    end

    def lodge_subtitle
      parts = []
      parts << "N°#{@lodge.number}" if @lodge.number.present?
      parts << @lodge.jurisdiction if @lodge.jurisdiction.present?
      parts << @lodge.orient if @lodge.orient.present?
      parts.compact.join(" · ")
    end

    def signature_line(name)
      name.presence || "________________________"
    end

    def current_office_holder_name(office_key)
      assignment = BrotherOfficeAssignment
        .joins(:office, :brother)
        .where(brothers: { lodge_id: @lodge.id })
        .where(offices: { key: office_key })
        .where("brother_office_assignments.start_date <= ?", @issued_on)
        .where("brother_office_assignments.end_date IS NULL OR brother_office_assignments.end_date >= ?", @issued_on)
        .order(start_date: :desc)
        .first

      assignment&.brother&.full_name
    end

    def asset_path(kind)
      Pdf::BrandAssets.path_for(kind)
    end

    def qr_code_io(url)
      require "rqrcode"
      png = ::RQRCode::QRCode.new(url).as_png(size: 180, border_modules: 1)
      StringIO.new(png.to_s)
    end

    def format_date(value)
      I18n.l(value, format: :long)
    rescue I18n::ArgumentError
      value.to_s
    end
  end
end
