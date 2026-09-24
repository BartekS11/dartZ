class FriendRequest < ApplicationRecord
  include HasPublicId
  public_id_prefix "fq_"

  STATUSES = %w[pending accepted declined cancelled].freeze

  belongs_to :requester, class_name: "User"
  belongs_to :recipient, class_name: "User"

  before_validation :set_pair_key, on: :create
  after_create_commit -> { PushNotifications::Notifier.friend_request(self) }, if: :web_push_enabled?
  after_update_commit -> { PushNotifications::Notifier.friendship_accepted(self) }, if: %i[accepted_now? web_push_enabled?]

  validates :status, inclusion: { in: STATUSES }
  validates :requester_id, comparison: { other_than: :recipient_id }

  scope :pending, -> { where(status: "pending") }
  scope :for_user, ->(user) { where(requester: user).or(where(recipient: user)) }

  def other_user(user)
    requester_id == user.id ? recipient : requester
  end

  def pending?
    status == "pending"
  end

  def resolve!(new_status)
    raise Social::Error.conflict("Request is no longer pending") unless pending?

    update!(status: new_status, resolved_at: Time.current)
  end

  private

  def accepted_now?
    saved_change_to_status? && status == "accepted"
  end

  def web_push_enabled?
    Rails.application.config.x.roadmap_features[:web_push]
  end

  def set_pair_key
    self.pair_key = [ requester_id, recipient_id ].compact.sort.join(":")
  end
end
