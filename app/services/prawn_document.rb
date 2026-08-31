# frozen_string_literal: true

class PrawnDocument
  FONT_FAMILY = "DejaVu"

  FONT_CANDIDATES = {
    normal: [
      Rails.root.join("vendor/fonts/DejaVuSans.ttf"),
      Pathname.new("/usr/share/fonts/truetype/dejavu/DejaVuSans.ttf")
    ],
    bold: [
      Rails.root.join("vendor/fonts/DejaVuSans-Bold.ttf"),
      Pathname.new("/usr/share/fonts/truetype/dejavu/DejaVuSans-Bold.ttf")
    ]
  }.freeze

  def self.build(**options, &block)
    pdf = Prawn::Document.new(page_size: "A4", **options)
    configure_fonts!(pdf)
    if block
      yield pdf
      pdf
    else
      pdf
    end
  end

  def self.configure_fonts!(pdf)
    normal = resolve_font(:normal)
    bold = resolve_font(:bold)
    return unless normal

    pdf.font_families.update(
      FONT_FAMILY => {
        normal: normal.to_s,
        bold: (bold || normal).to_s
      }
    )
    pdf.font FONT_FAMILY
  end

  def self.resolve_font(style)
    FONT_CANDIDATES.fetch(style).find { |path| File.exist?(path) }
  end

  private_class_method :resolve_font
end
