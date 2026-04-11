class Minute < ApplicationRecord
  belongs_to :created_by_user, class_name: "User", optional: true
  has_many_attached :documents

  before_validation :assign_folio, on: :create

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
    last_folio = Minute.where("folio LIKE ?", "#{prefix}%").order(:folio).pluck(:folio).last
    sequence = if last_folio.present?
                 last_folio.split("-").last.to_i + 1
    else
                 1
    end
    self.folio = "#{prefix}#{format('%04d', sequence)}"
  end
end
