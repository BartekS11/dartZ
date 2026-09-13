class User < ApplicationRecord
  has_secure_password
  ACCOUNT_TIERS = %w[free premium pro].freeze
  LOCALES = %w[en pl].freeze

  include BillableUser

  has_many :sessions, dependent: :destroy
  has_many :players, dependent: :destroy
  has_many :training_sessions, -> { kept }, inverse_of: :user
  has_many :all_training_sessions, class_name: "TrainingSession", dependent: :destroy
  has_many :training_drills, -> { kept }, inverse_of: :user
  has_many :all_training_drills, class_name: "TrainingDrill", dependent: :destroy
  has_many :practice_plans, -> { kept }, inverse_of: :user
  has_many :all_practice_plans, class_name: "PracticePlan", dependent: :destroy
  has_one :dart_setup, -> { kept }, inverse_of: :user
  has_many :all_dart_setups, class_name: "DartSetup", dependent: :destroy
  has_many :admin_tier_changes, dependent: :restrict_with_error
  has_many :admin_data_cleanups, dependent: :restrict_with_error
  has_many :admin_data_cleanup_events, dependent: :restrict_with_error

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
