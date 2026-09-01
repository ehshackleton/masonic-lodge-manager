# frozen_string_literal: true

module Pdf
  class InstitutionalReport
    ACCENT = "C9A227"
    MUTED = "666666"
    HEADER_FILL = "F5F0E6"
    ROW_ALT_FILL = "FAFAF8"
    BORDER = "CCCCCC"
    CELL_PADDING = 5
    MIN_ROW_HEIGHT = 20
    FOOTER_RESERVE = 72
    FONT_SIZE = 9
    HEADER_FONT_SIZE = 8

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
        draw_header(pdf)
        block.call(self, pdf) if block
        draw_footer(pdf)
      end.render
    end

    def section(pdf, title)
      ensure_space(pdf, 44)
      pdf.move_down 6
      pdf.stroke_color ACCENT
      pdf.line_width 0.75
      pdf.stroke_horizontal_rule
      pdf.move_down 8
      pdf.fill_color "000000"
      pdf.text title, size: 12, style: :bold
      pdf.move_down 6
      yield
    end

    def table(pdf, headers:, rows:, widths: nil)
      return if headers.blank?

      col_widths = normalize_widths(pdf, headers.size, widths)
      inner_widths = col_widths.map { |width| [ width - (CELL_PADDING * 2), 12 ].max }

      draw_table_row(pdf, headers, col_widths, inner_widths, header: true)
      rows.each_with_index do |row, index|
        draw_table_row(pdf, row, col_widths, inner_widths, header: false, alt: index.odd?)
      end
      pdf.move_down 8
    end

    def key_values(pdf, pairs)
      pairs.each do |label, value|
        ensure_space(pdf, 18)
        pdf.text "<color rgb='#{MUTED}'><b>#{escape_html(label)}:</b></color> #{escape_html(value.to_s)}",
                 size: 10,
                 inline_format: true,
                 leading: 2
      end
      pdf.move_down 4
    end

    def paragraph(pdf, text, size: 10, muted: false)
      content = text.to_s.strip
      return if content.blank?

      ensure_space(pdf, 24)
      pdf.fill_color muted ? MUTED : "000000"
      pdf.text content, size: size, leading: 3
      pdf.fill_color "000000"
      pdf.move_down 6
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
      pdf.move_down 6

      @meta_lines.each do |line|
        pdf.text line.to_s, align: :center, size: 8, color: MUTED
      end

      pdf.move_down 8
      pdf.stroke_color ACCENT
      pdf.line_width 0.75
      pdf.stroke_horizontal_rule
      pdf.move_down 10
    end

    def draw_continuation_header(pdf)
      pdf.move_down 8
      pdf.text @title.to_s, align: :center, size: 11, style: :bold
      pdf.move_down 6
      pdf.stroke_color ACCENT
      pdf.line_width 0.75
      pdf.stroke_horizontal_rule
      pdf.move_down 10
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

    def draw_table_row(pdf, cells, col_widths, inner_widths, header: false, alt: false)
      values = cells.map { |cell| sanitize_cell(cell) }
      font_size = header ? HEADER_FONT_SIZE : FONT_SIZE
      style = header ? :bold : :normal

      row_height = values.each_with_index.map do |value, index|
        cell_height(pdf, value, inner_widths[index], size: font_size, style: style)
      end.max

      ensure_space(pdf, row_height + 2)
      y_top = pdf.cursor
      table_width = col_widths.sum

      pdf.fill_color header ? HEADER_FILL : (alt ? ROW_ALT_FILL : "FFFFFF")
      pdf.fill_rectangle [ 0, y_top ], table_width, row_height
      pdf.fill_color "000000"

      x = 0
      values.each_with_index do |value, index|
        pdf.text_box value,
                     at: [ x + CELL_PADDING, y_top - CELL_PADDING ],
                     width: inner_widths[index],
                     height: row_height - (CELL_PADDING * 2),
                     size: font_size,
                     style: style,
                     valign: :center

        if index.positive?
          pdf.stroke_color BORDER
          pdf.line_width 0.25
          pdf.stroke_vertical_line y_top, y_top - row_height, at: x
        end

        x += col_widths[index]
      end

      pdf.stroke_color BORDER
      pdf.line_width 0.25
      pdf.stroke_vertical_line y_top, y_top - row_height, at: table_width
      pdf.horizontal_line 0, table_width, at: y_top - row_height

      pdf.move_down row_height
    end

    def cell_height(pdf, text, width, size:, style:)
      return MIN_ROW_HEIGHT if text.blank?

      content_height = pdf.height_of(text, width: width, size: size, style: style)
      [ content_height + (CELL_PADDING * 2), MIN_ROW_HEIGHT ].max
    end

    def normalize_widths(pdf, count, widths)
      total = pdf.bounds.width.to_f

      weights =
        if widths.present? && widths.size == count
          widths.map(&:to_f)
        else
          Array.new(count, total / count.to_f)
        end

      sum = weights.sum
      scaled = weights.map { |weight| ((weight / sum) * total).floor }
      scaled[-1] += (total - scaled.sum).to_i
      scaled
    end

    def ensure_space(pdf, needed)
      return if pdf.cursor >= needed + FOOTER_RESERVE

      pdf.start_new_page
      draw_page_frame(pdf)
      draw_continuation_header(pdf)
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

    def sanitize_cell(value)
      value.to_s.gsub(/\s+/, " ").strip
    end

    def escape_html(text)
      text.to_s.gsub("&", "&amp;").gsub("<", "&lt;").gsub(">", "&gt;")
    end
  end
end
