class Correspondence < ApplicationRecord
  belongs_to :lodge
  belongs_to :created_by_user, class_name: "User", optional: true
  has_many_attached :documents

  before_validation :assign_folio, on: :create

  enum :direction, {
    incoming: "incoming",
    outgoing: "outgoing"
  }, prefix: true

  enum :status, {
    draft: "draft",
    review: "review",
    approved: "approved",
    published: "published",
    pending: "pending",
    answered: "answered",
    archived: "archived"
  }, prefix: true

  enum :confidentiality_level, {
    public_doc: "public",
    internal: "internal",
    reserved: "reserved",
    confidential: "confidential"
  }, prefix: true

  validates :subject, presence: true
  validates :direction, presence: true

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

    year = (sent_on || received_on || Date.current).year
    prefix = "CORR-#{year}-"
    last_folio = Correspondence.where("folio LIKE ?", "#{prefix}%").order(:folio).pluck(:folio).last
    sequence = if last_folio.present?
                 last_folio.split("-").last.to_i + 1
    else
                 1
    end
    self.folio = "#{prefix}#{format('%04d', sequence)}"
  end
end
