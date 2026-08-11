class User < ApplicationRecord
  has_secure_password
  ACCOUNT_TIERS = %w[free premium pro].freeze

  has_many :sessions, dependent: :destroy
  has_many :players, dependent: :destroy
  has_one :dart_setup, dependent: :destroy

  normalizes :email_address, with: ->(e) { e.strip.downcase }
  normalizes :nickname, with: ->(n) { n.to_s.strip.presence }

  validates :email_address, presence: true, uniqueness: { case_sensitive: false }
  validates :nickname, length: { maximum: 20 }, allow_blank: true
  validates :account_tier, presence: true, inclusion: { in: ACCOUNT_TIERS }

  def display_name
    nickname.presence || email_address
  end

  def premium_access?
    return false if account_tier == "free"
    return true if premium_access_expires_at.blank?

    premium_access_expires_at.future?
  end
end
