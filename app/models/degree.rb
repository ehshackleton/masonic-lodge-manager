class Degree < ApplicationRecord
  has_many :brothers, foreign_key: :current_degree_id, dependent: :nullify
  has_many :masonic_works, dependent: :nullify
  has_many :brother_degree_histories, dependent: :restrict_with_error

  validates :key, presence: true, uniqueness: true
  validates :name, presence: true
end
