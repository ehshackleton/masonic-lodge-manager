class Role < ApplicationRecord
  has_many :user_roles, dependent: :destroy
  has_many :users, through: :user_roles

  validates :key, :name, presence: true
  validates :key, uniqueness: true
end
