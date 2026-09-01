# frozen_string_literal: true

require "digest"

module BrandHelper
  MASTER_LOGO = %w[logo-amenti.png logo-amenti-light.png logo-amenti.jpg].freeze
  MASTER_LIGHT = %w[logo-amenti-light.png logo-amenti.png].freeze
  HERO_LOGO_DARK = %w[logo-amenti.png logo-amenti-hero.png logo-amenti-card.png].freeze
  HERO_LOGO_LIGHT = %w[logo-amenti-light.png logo-amenti.png logo-amenti-hero.png].freeze
  HERO_LOGO = HERO_LOGO_DARK.freeze
  MARK_LOGO = %w[insignia-sello.png logo-amenti-badge.png logo-amenti-mark.png].freeze
  SEAL_LOGO = %w[insignia-sello.png logo-amenti-badge.png].freeze

  def amenti_asset_path(*candidates)
    found = candidates.flatten.find { |name| File.exist?(Rails.root.join("public/images", name)) }
    return unless found

    file = Rails.root.join("public/images", found)
    version = Digest::SHA256.file(file).hexdigest.first(12)
    "/images/#{found}?v=#{version}"
  end

  def amenti_master_logo_path
    amenti_asset_path(MASTER_LOGO)
  end

  def amenti_master_light_path
    amenti_asset_path(MASTER_LIGHT)
  end

  def amenti_hero_logo_path
    amenti_asset_path(HERO_LOGO)
  end

  def amenti_hero_logo_dark_path
    amenti_asset_path(HERO_LOGO_DARK)
  end

  def amenti_hero_logo_light_path
    amenti_asset_path(HERO_LOGO_LIGHT)
  end

  def amenti_mark_path
    amenti_asset_path(MARK_LOGO)
  end

  def amenti_seal_path
    amenti_asset_path(SEAL_LOGO)
  end
end
