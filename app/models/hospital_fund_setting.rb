class HospitalFundSetting < ApplicationRecord
  belongs_to :lodge

  validates :contribution_amount, numericality: { greater_than_or_equal_to: 0 }
  validates :death_benefit_amount, numericality: { greater_than_or_equal_to: 0 }
  validates :currency, presence: true
end
