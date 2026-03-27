class User < ApplicationRecord
  has_secure_password
  has_many :registered_payments, class_name: "Payment", foreign_key: :received_by_user_id, dependent: :nullify
  has_many :monthly_closures, class_name: "MonthlyClosure", foreign_key: :closed_by_user_id, dependent: :nullify
  has_many :review_assigned_works, class_name: "MasonicWork", foreign_key: :reviewer_user_id, dependent: :nullify
  has_many :work_reviews, class_name: "WorkReview", foreign_key: :reviewer_user_id, dependent: :nullify
  has_many :user_roles, dependent: :destroy
  has_many :roles, through: :user_roles

  before_validation :normalize_email

  validates :email, presence: true, uniqueness: true
  validates :password, length: { minimum: 12 }, allow_nil: true

  def locked?
    locked_at.present?
  end

  def has_role?(role_key)
    roles.where(key: role_key.to_s).exists?
  end

  def can_manage_masonic_work_action?(action)
    key = action.to_s
    return true if has_role?(:superadmin)

    case key
    when "submit_review"
      has_role?(:secretario) || has_role?(:work_reviewer)
    when "approve"
      has_role?(:secretario) || has_role?(:work_approver)
    when "mark_presented"
      has_role?(:secretario) || has_role?(:work_presenter)
    when "archive"
      has_role?(:secretario) || has_role?(:work_archiver)
    when "create_review", "destroy_review"
      has_role?(:secretario) || has_role?(:work_reviewer)
    else
      false
    end
  end

  def can_access_module?(module_key)
    key = module_key.to_s
    return true if has_role?(:superadmin)

    case key
    when "works"
      has_role?(:secretario) || has_role?(:work_reviewer) || has_role?(:work_approver) || has_role?(:work_presenter) || has_role?(:work_archiver)
    when "secretariat"
      has_role?(:secretario) || has_role?(:secretariat_manager) || has_role?(:minute_editor) || has_role?(:minute_approver) || has_role?(:correspondence_editor) || has_role?(:correspondence_approver)
    when "treasury"
      has_role?(:tesoreria_manager) || has_role?(:tesoreria_operator) || has_role?(:tesoreria_closer) || has_role?(:tesoreria_exporter)
    else
      false
    end
  end

  def can_manage_secretariat_action?(action)
    key = action.to_s
    return true if has_role?(:superadmin) || has_role?(:secretario) || has_role?(:secretariat_manager)

    case key
    when "minutes_read", "correspondences_read"
      has_role?(:minute_editor) || has_role?(:minute_approver) || has_role?(:correspondence_editor) || has_role?(:correspondence_approver)
    when "minute_write"
      has_role?(:minute_editor)
    when "minute_approve"
      has_role?(:minute_approver)
    when "correspondence_write"
      has_role?(:correspondence_editor)
    when "correspondence_approve"
      has_role?(:correspondence_approver)
    else
      false
    end
  end

  def can_manage_treasury_action?(action)
    key = action.to_s
    return true if has_role?(:superadmin) || has_role?(:tesoreria_manager)

    case key
    when "read"
      has_role?(:tesoreria_operator) || has_role?(:tesoreria_closer) || has_role?(:tesoreria_exporter)
    when "operate"
      has_role?(:tesoreria_operator)
    when "close_period"
      has_role?(:tesoreria_closer)
    when "export"
      has_role?(:tesoreria_exporter)
    else
      false
    end
  end

  def can_manage_work_approval?
    can_manage_masonic_work_action?(:approve) && can_manage_masonic_work_action?(:archive)
  end

  private

  def normalize_email
    self.email = email.to_s.strip.downcase
  end
end
