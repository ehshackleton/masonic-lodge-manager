# frozen_string_literal: true

require "zip"

module Amenti
  # Minimal ODS sheet reader (no PII logged).
  class OdsReader
    def initialize(path)
      @path = path.to_s
    end

    def sheets
      @sheets ||= begin
        xml = Zip::File.open(@path) { |z| z.read("content.xml") }
        doc = Nokogiri::XML(xml)
        doc.remove_namespaces!
        result = {}
        doc.xpath("//table").each do |table|
          name = table["name"]
          result[name] = rows_for(table)
        end
        result
      end
    end

    def sheet(name)
      sheets.fetch(name)
    end

    def sheet_as_hashes(name)
      rows = sheet(name)
      return [] if rows.empty?

      headers = rows.first.map { |h| h.to_s.strip }
      rows.drop(1).map do |row|
        headers.each_with_index.to_h { |h, i| [ h, row[i].to_s.strip ] }
      end
    end

    private

    def rows_for(table, max_cols: 60)
      rows = []
      table.xpath("./table-row").each do |row|
        cells = []
        col = 0
        row.xpath("./table-cell|./covered-table-cell").each do |cell|
          repeat = (cell["number-columns-repeated"] || 1).to_i
          value = cell.name == "table-cell" ? cell_text(cell) : ""
          repeat.times do
            break if col >= max_cols

            cells << value
            col += 1
          end
          break if col >= max_cols
        end
        cells.pop while cells.last == ""
        rows << cells if cells.any? { |c| c.present? }
      end
      rows
    end

    def cell_text(cell)
      cell.xpath(".//p").map { |p| p.text.to_s }.join(" ").gsub(/\s+/, " ").strip
    end
  end
end
