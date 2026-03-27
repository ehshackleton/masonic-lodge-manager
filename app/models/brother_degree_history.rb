class BrotherDegreeHistory < ApplicationRecord
  belongs_to :brother
  belongs_to :degree

  validates :degree_id, presence: true
  validates :ceremony_date, presence: true
end
