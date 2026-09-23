class User < ApplicationRecord
  has_secure_password
  ACCOUNT_TIERS = %w[free premium pro].freeze
  LOCALES = %w[en pl nl es].freeze

  include BillableUser
  include HasPublicId
  public_id_prefix "u_"

  FRIEND_REQUEST_POLICIES = %w[anyone share_code_only nobody].freeze
  CHALLENGE_POLICIES = %w[friends nobody].freeze

  before_validation :ensure_friend_share_code, on: :create

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
  has_many :sent_friend_requests, class_name: "FriendRequest", foreign_key: :requester_id, dependent: :destroy
  has_many :received_friend_requests, class_name: "FriendRequest", foreign_key: :recipient_id, dependent: :destroy
  has_many :friendships_as_low, class_name: "Friendship", foreign_key: :user_low_id, dependent: :destroy
  has_many :friendships_as_high, class_name: "Friendship", foreign_key: :user_high_id, dependent: :destroy
  has_many :blocks_created, class_name: "UserBlock", foreign_key: :blocker_id, dependent: :destroy
  has_many :blocks_received, class_name: "UserBlock", foreign_key: :blocked_id, dependent: :destroy
  has_many :sent_match_challenges, class_name: "MatchChallenge", foreign_key: :challenger_id, dependent: :destroy
  has_many :received_match_challenges, class_name: "MatchChallenge", foreign_key: :challenged_id, dependent: :destroy
  has_many :push_subscriptions, dependent: :destroy
  has_one :notification_preference, dependent: :destroy

  normalizes :email_address, with: ->(e) { e.strip.downcase }
  normalizes :nickname, with: ->(n) { n.to_s.strip.presence }
  normalizes :locale, with: ->(locale) { locale.to_s.strip.downcase.presence || I18n.default_locale.to_s }

  validates :email_address, presence: true, uniqueness: { case_sensitive: false }
  validates :onboarding_guide_version, numericality: { only_integer: true, greater_than_or_equal_to: 0 }
  validates :nickname, length: { maximum: 20 }, allow_blank: true
  validates :account_tier, presence: true, inclusion: { in: ACCOUNT_TIERS }
  validates :manual_tier_override, inclusion: { in: ACCOUNT_TIERS }, allow_nil: true
  validates :locale, presence: true, inclusion: { in: LOCALES }
  validates :friend_share_code, presence: true, uniqueness: true, format: { with: /\A[A-Z0-9]{12}\z/ }
  validates :friend_request_policy, inclusion: { in: FRIEND_REQUEST_POLICIES }
  validates :challenge_policy, inclusion: { in: CHALLENGE_POLICIES }
  validates :discoverable_by_nickname, inclusion: { in: [ true, false ] }

  def display_name
    nickname.presence || email_address
  end

  # Existing administrator routes intentionally remain numeric and private.
  def to_param
    id.to_s
  end

  def friendships
    Friendship.for_user(self)
  end

  def friends
    User.where(id: friendships.select(:user_low_id)).or(User.where(id: friendships.select(:user_high_id))).where.not(id: id)
  end

  private

  def ensure_friend_share_code
    return if friend_share_code.present?

    loop do
      self.friend_share_code = SecureRandom.alphanumeric(12).upcase
      break unless User.exists?(friend_share_code: friend_share_code)
    end
  end
end
