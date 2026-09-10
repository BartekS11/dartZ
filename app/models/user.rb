class User < ApplicationRecord
  has_secure_password
  ACCOUNT_TIERS = %w[free premium pro].freeze
  LOCALES = %w[en pl].freeze

  include BillableUser

  has_many :sessions, dependent: :destroy
  has_many :players, dependent: :destroy
  has_many :training_sessions, dependent: :destroy
  has_many :practice_plans, dependent: :destroy
  has_one :dart_setup, dependent: :destroy
  has_many :admin_tier_changes, dependent: :restrict_with_error

  normalizes :email_address, with: ->(e) { e.strip.downcase }
  normalizes :nickname, with: ->(n) { n.to_s.strip.presence }
  normalizes :locale, with: ->(locale) { locale.to_s.strip.downcase.presence || I18n.default_locale.to_s }

  validates :email_address, presence: true, uniqueness: { case_sensitive: false }
  validates :nickname, length: { maximum: 20 }, allow_blank: true
  validates :account_tier, presence: true, inclusion: { in: ACCOUNT_TIERS }
  validates :manual_tier_override, inclusion: { in: ACCOUNT_TIERS }, allow_nil: true
  validates :locale, presence: true, inclusion: { in: LOCALES }

  def display_name
    nickname.presence || email_address
  end
end
