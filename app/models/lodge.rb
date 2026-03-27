class Lodge < ApplicationRecord
  has_many :brothers, dependent: :restrict_with_error
  has_many :masonic_works, dependent: :restrict_with_error
  has_one :treasury_setting, dependent: :destroy
  has_one :hospital_fund_setting, dependent: :destroy
  has_many :monthly_closures, dependent: :destroy
  has_many :ledger_entries, dependent: :destroy
  has_many :hospital_fund_transactions, dependent: :destroy

  validates :name, presence: true
end
