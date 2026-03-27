class MasonicWork < ApplicationRecord
  belongs_to :lodge
  belongs_to :brother
  belongs_to :degree, optional: true
  belongs_to :reviewer_user, class_name: "User", optional: true
  has_many :work_reviews, dependent: :destroy
  has_many_attached :documents

  enum :status, {
    assigned: "assigned",
    draft: "draft",
    in_review: "in_review",
    approved: "approved",
    presented: "presented",
    archived: "archived"
  }, prefix: true

  validates :title, :status, presence: true

  def can_submit_review?
    status_assigned? || status_draft?
  end

  def can_approve?
    status_in_review?
  end

  def can_mark_presented?
    status_approved?
  end

  def can_archive?
    status_presented? || status_approved?
  end
end
