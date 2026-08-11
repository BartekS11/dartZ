class User < ApplicationRecord
  has_secure_password
  ACCOUNT_TIERS = %w[free premium pro].freeze
  LOCALES = %w[en pl].freeze

  has_many :sessions, dependent: :destroy
  has_many :players, dependent: :destroy
  has_one :dart_setup, dependent: :destroy

  normalizes :email_address, with: ->(e) { e.strip.downcase }
  normalizes :nickname, with: ->(n) { n.to_s.strip.presence }
  normalizes :locale, with: ->(locale) { locale.to_s.strip.downcase.presence || I18n.default_locale.to_s }

  validates :email_address, presence: true, uniqueness: { case_sensitive: false }
  validates :nickname, length: { maximum: 20 }, allow_blank: true
  validates :account_tier, presence: true, inclusion: { in: ACCOUNT_TIERS }
  validates :locale, presence: true, inclusion: { in: LOCALES }

  def display_name
    nickname.presence || email_address
  end

  def premium_access?
    return false if account_tier == "free"
    return true if premium_access_expires_at.blank?

    premium_access_expires_at.future?
  end
end
