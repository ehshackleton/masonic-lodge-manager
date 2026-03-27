class Brother < ApplicationRecord
  belongs_to :lodge
  belongs_to :current_degree, class_name: "Degree", optional: true
  has_many :brother_degree_histories, dependent: :destroy
  has_many :brother_office_assignments, dependent: :destroy
  has_many :offices, through: :brother_office_assignments
  has_many :charges, dependent: :restrict_with_error
  has_many :payments, dependent: :restrict_with_error
  has_many :masonic_works, dependent: :restrict_with_error
  has_many_attached :documents

  enum :membership_status, {
    active: "active",
    inactive: "inactive",
    suspended: "suspended",
    retired: "retired",
    deceased: "deceased"
  }, prefix: true

  validates :registry_number, presence: true
  validates :first_name, presence: true
  validates :last_name, presence: true
  validates :registry_number, uniqueness: true

  scope :ordered, -> { order(last_name: :asc, first_name: :asc) }

  def full_name
    [first_name, last_name].compact.join(" ").strip
  end
end
