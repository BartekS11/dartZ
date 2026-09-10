class AdminTierChange < ApplicationRecord
  ACTIONS = %w[set clear].freeze

  belongs_to :admin_user
  belongs_to :user

  validates :action, inclusion: { in: ACTIONS }
  validates :managed_tier, :previous_effective_tier, :new_effective_tier,
    inclusion: { in: User::ACCOUNT_TIERS }
  validates :previous_override, :new_override,
    inclusion: { in: User::ACCOUNT_TIERS }, allow_nil: true
  validates :reason, length: { maximum: 2000 }, allow_blank: true

  before_update { throw :abort }
  before_destroy { throw :abort }
end
