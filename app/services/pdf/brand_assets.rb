# frozen_string_literal: true

module Pdf
  module BrandAssets
    ASSETS = {
      logo: %w[logo-amenti-light.png logo-amenti.png logo-amenti-hero.png].freeze,
      insignia: %w[insignia-sello.png logo-amenti-badge.png].freeze,
      mark: %w[logo-amenti-badge.png logo-amenti-mark.png].freeze
    }.freeze

    module_function

    def path_for(kind)
      ASSETS.fetch(kind).each do |name|
        file = Rails.root.join("public/images", name)
        return file.to_s if File.exist?(file)
      end
      nil
    end
  end
end
