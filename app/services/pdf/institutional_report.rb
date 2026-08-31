# frozen_string_literal: true

module Pdf
  class InstitutionalReport
    ACCENT = "C9A227"
    MUTED = "666666"
    HEADER_FILL = "F5F0E6"
    ROW_ALT_FILL = "FAFAF8"

    def initialize(title:, subtitle: nil, lodge: nil, meta_lines: [], emitted_by: nil, confidential: true)
      @title = title
      @subtitle = subtitle
      @lodge = lodge
      @meta_lines = Array(meta_lines)
      @emitted_by = emitted_by
      @confidential = confidential
    end

    def render(&block)
      PrawnDocument.build(margin: 48) do |pdf|
        draw_page_frame(pdf)
        body_top = draw_header(pdf)
        pdf.bounding_box([ 0, body_top ], width: pdf.bounds.width, height: body_top - 64) do
          block.call(self, pdf) if block
        end
        draw_footer(pdf)
      end.render
    end

    def section(pdf, title)
      ensure_space(pdf, 40)
      pdf.move_down 8
      pdf.stroke_color ACCENT
      pdf.line_width 0.75
      pdf.stroke_horizontal_rule
      pdf.move_down 10
      pdf.fill_color "000000"
      pdf.text title, size: 12, style: :bold
      pdf.move_down 8
      yield
    end

    def table(pdf, headers:, rows:, widths: nil)
      return if headers.blank?

      col_widths = normalize_widths(pdf, headers.size, widths)
      row_height = 18

      draw_table_row(pdf, headers, col_widths, row_height, header: true)
      rows.each_with_index do |row, index|
        ensure_space(pdf, row_height + 4)
        draw_table_row(pdf, row, col_widths, row_height, header: false, alt: index.odd?)
      end
      pdf.move_down 8
    end

    def key_values(pdf, pairs)
      pairs.each do |label, value|
        ensure_space(pdf, 16)
        pdf.text "<color rgb='#{MUTED}'><b>#{escape_html(label)}:</b></color> #{escape_html(value.to_s)}",
                 size: 10,
                 inline_format: true
      end
    end

    def paragraph(pdf, text, size: 10, muted: false)
      ensure_space(pdf, 20)
      pdf.fill_color muted ? MUTED : "000000"
      pdf.text text.to_s, size: size
      pdf.fill_color "000000"
    end

    private

    def draw_page_frame(pdf)
      pdf.canvas do
        pdf.stroke_color ACCENT
        pdf.line_width 1
        inset = 24
        width = pdf.page.dimensions[2] - (inset * 2)
        height = pdf.page.dimensions[3] - (inset * 2)
        pdf.stroke_rectangle [ inset, pdf.page.dimensions[3] - inset ], width, height
      end
    end

    def draw_header(pdf)
      insignia = BrandAssets.path_for(:insignia)
      logo = BrandAssets.path_for(:logo)
      top = pdf.cursor

      if insignia
        pdf.image insignia, at: [ 0, top ], width: 46
        pdf.image insignia, at: [ pdf.bounds.width - 46, top ], width: 46
      end

      if logo
        pdf.image logo, at: [ (pdf.bounds.width - 96) / 2, top + 2 ], width: 96
      end

      pdf.move_down 52
      pdf.text @title.to_s, align: :center, size: 15, style: :bold
      pdf.text lodge_heading, align: :center, size: 9, color: MUTED if lodge_heading.present?
      pdf.text @subtitle.to_s, align: :center, size: 10, color: MUTED if @subtitle.present?
      pdf.move_down 8

      @meta_lines.each do |line|
        pdf.text line.to_s, align: :center, size: 8, color: MUTED
      end

      pdf.move_down 10
      pdf.stroke_color ACCENT
      pdf.line_width 0.75
      pdf.stroke_horizontal_rule
      pdf.move_down 12
      pdf.cursor
    end

    def draw_footer(pdf)
      pdf.repeat(:all) do
        pdf.canvas do
          pdf.fill_color MUTED
          pdf.text_box footer_text,
                      at: [ 48, 42 ],
                      width: pdf.page.dimensions[2] - 96,
                      height: 24,
                      size: 7,
                      align: :center,
                      valign: :center
          pdf.fill_color "000000"
        end
      end

      pdf.number_pages "Pagina <page> de <total>",
                       at: [ pdf.bounds.left, -8 ],
                       width: pdf.bounds.width,
                       align: :right,
                       size: 7,
                       color: MUTED
    end

    def draw_table_row(pdf, cells, widths, height, header: false, alt: false)
      x = 0
      y = pdf.cursor

      if header
        pdf.fill_color HEADER_FILL
        pdf.fill_rectangle [ x, y + 2 ], widths.sum, height
        pdf.fill_color "000000"
      elsif alt
        pdf.fill_color ROW_ALT_FILL
        pdf.fill_rectangle [ x, y + 2 ], widths.sum, height - 1
        pdf.fill_color "000000"
      end

      cells.each_with_index do |cell, index|
        pdf.bounding_box([ x, y ], width: widths[index], height: height) do
          pdf.text cell.to_s,
                   size: header ? 8 : 8,
                   style: header ? :bold : :normal,
                   valign: :center,
                   overflow: :shrink_to_fit,
                   min_font_size: 6
        end
        x += widths[index]
      end

      pdf.stroke_color "CCCCCC"
      pdf.line_width  0.25
      pdf.horizontal_line 0, widths.sum, at: y - height + 2
      pdf.move_down height
    end

    def normalize_widths(pdf, count, widths)
      return widths if widths.present? && widths.size == count

      total = pdf.bounds.width
      base = (total / count.to_f).floor
      Array.new(count, base)
    end

    def ensure_space(pdf, needed)
      return if pdf.cursor > needed + 72

      pdf.start_new_page
      pdf.move_down 8
    end

    def lodge_heading
      return unless @lodge

      parts = [ @lodge.name ]
      parts << "N°#{@lodge.number}" if @lodge.number.present?
      parts << @lodge.jurisdiction if @lodge.jurisdiction.present?
      parts.join(" · ")
    end

    def footer_text
      parts = []
      parts << (@lodge&.name || "Amenti Diez N°31")
      parts << "Documento institucional interno" if @confidential
      parts << "Emitido por: #{@emitted_by}" if @emitted_by.present?
      parts << I18n.l(Date.current, format: :long)
      parts.join(" · ")
    end

    def escape_html(text)
      text.to_s.gsub("&", "&amp;").gsub("<", "&lt;").gsub(">", "&gt;")
    end
  end
end
