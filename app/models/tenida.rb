class Tenida < ApplicationRecord
  belongs_to :lodge
  belongs_to :degree, optional: true
  belongs_to :presiding_brother, class_name: "Brother", optional: true
  has_many :minutes, dependent: :nullify
  has_many :workspace_links, as: :linkable, dependent: :destroy

  def calendar_link
    workspace_links.calendar_events.order(created_at: :desc).first
  end

  before_validation :assign_code, on: :create

  enum :tenida_type, {
    regular: "regular",
    blanca: "blanca",
    extraordinaria: "extraordinaria",
    instalacion: "instalacion",
    otra: "otra"
  }, prefix: true

  enum :status, {
    planned: "planned",
    cited: "cited",
    held: "held",
    minutes_draft: "minutes_draft",
    in_review: "in_review",
    approved: "approved",
    archived: "archived",
    cancelled: "cancelled"
  }, prefix: true

  # Quién preside esa Tenida (no confundir con cargo titular del período).
  enum :presiding_capacity, {
    titular: "titular",
    adjunto: "adjunto",
    pt: "pt",
    otro: "otro"
  }, prefix: true, allow_nil: true

  validates :held_on, :tenida_type, :status, presence: true
  validates :code, uniqueness: { scope: :lodge_id }, allow_nil: true
  validates :place, length: { maximum: 200 }, allow_blank: true
  validate :presiding_brother_belongs_to_lodge

  scope :for_lodge, ->(lodge) { where(lodge_id: lodge.is_a?(Lodge) ? lodge.id : lodge) }
  scope :ordered, -> { order(held_on: :desc, code: :desc) }
  scope :upcoming, ->(from: Date.current) { where("held_on >= ?", from).where.not(status: %w[cancelled archived]) }
  scope :attention, -> {
    where(status: %w[planned cited held minutes_draft in_review])
  }

  def label
    parts = [ code.presence, held_on&.strftime("%d/%m/%Y"), degree&.name, tenida_type.humanize ].compact
    parts.join(" · ")
  end

  def can_mark_held?
    status_planned? || status_cited?
  end

  def can_cancel?
    !status_cancelled? && !status_archived? && !status_approved?
  end

  def sync_status_from_minutes!
    return if status_cancelled? || status_archived?

    latest = minutes.order(updated_at: :desc).first
    return unless latest

    new_status = case latest.status
                 when "draft" then "minutes_draft"
                 when "review" then "in_review"
                 when "approved", "published" then "approved"
                 else status
    end
    update!(status: new_status) if new_status != status
  end

  private

  def assign_code
    return if code.present? || lodge_id.blank?

    year = (held_on || Date.current).year
    prefix = "TEN-#{year}-"
    last_code = Tenida.where(lodge_id: lodge_id).where("code LIKE ?", "#{prefix}%").order(:code).pluck(:code).last
    sequence = last_code.present? ? last_code.split("-").last.to_i + 1 : 1
    self.code = "#{prefix}#{format('%04d', sequence)}"
  end

  def presiding_brother_belongs_to_lodge
    return if presiding_brother.blank? || lodge_id.blank?
    return if presiding_brother.lodge_id == lodge_id

    errors.add(:presiding_brother_id, "debe pertenecer a la misma logia")
  end
end
