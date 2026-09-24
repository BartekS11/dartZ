class MatchChallenge < ApplicationRecord
  include HasPublicId
  public_id_prefix "ch_"

  TTL = 24.hours
  STATUSES = %w[pending accepted declined cancelled expired].freeze

  belongs_to :challenger, class_name: "User"
  belongs_to :challenged, class_name: "User"
  belongs_to :match

  before_validation :set_defaults, on: :create
  after_create_commit -> { PushNotifications::Notifier.match_challenge(self) }, if: :web_push_enabled?

  validates :status, inclusion: { in: STATUSES }
  validates :challenger_id, comparison: { other_than: :challenged_id }
  validates :expires_at, presence: true

  scope :pending, -> { where(status: "pending") }
  scope :for_user, ->(user) { where(challenger: user).or(where(challenged: user)) }

  def other_user(user)
    challenger_id == user.id ? challenged : challenger
  end

  def pending?
    status == "pending" && !expired?
  end

  def expired?
    status == "expired" || (status == "pending" && expires_at <= Time.current)
  end

  def expire!
    update!(status: "expired", resolved_at: Time.current) if status == "pending"
  end

  def resolve!(new_status)
    raise Social::Error.conflict("Challenge is no longer pending") unless pending?

    update!(status: new_status, resolved_at: Time.current)
  end

  private

  def web_push_enabled?
    Rails.application.config.x.roadmap_features[:web_push]
  end

  def set_defaults
    self.pair_key = [ challenger_id, challenged_id ].compact.sort.join(":")
    self.expires_at ||= TTL.from_now
  end
end
