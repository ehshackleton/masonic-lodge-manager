class Minute < ApplicationRecord
  belongs_to :lodge
  belongs_to :tenida, optional: true
  belongs_to :created_by_user, class_name: "User", optional: true
  has_many_attached :documents

  before_validation :assign_folio, on: :create
  after_save :sync_tenida_status
  after_destroy :sync_tenida_status

  enum :status, {
    draft: "draft",
    review: "review",
    approved: "approved",
    published: "published"
  }, prefix: true

  enum :visibility, {
    internal: "internal",
    restricted: "restricted",
    confidential: "confidential"
  }, prefix: true

  validates :title, presence: true
  validates :session_date, presence: true
  validates :lodge, presence: true
  validate :tenida_belongs_to_lodge

  scope :for_lodge, ->(lodge) { where(lodge_id: lodge.is_a?(Lodge) ? lodge.id : lodge) }
  scope :ordered, -> { order(session_date: :desc, folio: :desc) }
  scope :needing_attention, -> { where(status: %w[draft review approved]) }

  def can_submit_review?
    status_draft?
  end

  def can_approve?
    status_review?
  end

  def can_publish?
    status_approved?
  end

  private

  def assign_folio
    return if folio.present?

    year = (session_date || Date.current).year
    prefix = "ACTA-#{year}-"
    scope = lodge_id.present? ? Minute.where(lodge_id: lodge_id) : Minute.all
    last_folio = scope.where("folio LIKE ?", "#{prefix}%").order(:folio).pluck(:folio).last
    sequence = if last_folio.present?
                 last_folio.split("-").last.to_i + 1
    else
                 1
    end
    self.folio = "#{prefix}#{format('%04d', sequence)}"
  end

  def tenida_belongs_to_lodge
    return if tenida.blank? || lodge_id.blank?
    return if tenida.lodge_id == lodge_id

    errors.add(:tenida_id, "debe pertenecer a la misma logia")
  end

  def sync_tenida_status
    tenida&.sync_status_from_minutes!
  end
end
