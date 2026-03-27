class WorkReview < ApplicationRecord
  belongs_to :masonic_work
  belongs_to :reviewer_user, class_name: "User"

  enum :status, {
    commented: "commented",
    needs_changes: "needs_changes",
    approved: "approved"
  }, prefix: true

  validates :reviewed_on, :status, presence: true
end
