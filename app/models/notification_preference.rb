class NotificationPreference < ApplicationRecord
  CATEGORIES = %w[friend_requests friendship_acceptance match_challenges tournament_round_ready].freeze

  belongs_to :user

  validates :user_id, uniqueness: true
  validates(*CATEGORIES, inclusion: { in: [ true, false ] })

  def enabled?(category)
    category = category.to_s
    CATEGORIES.include?(category) && public_send(category)
  end
end
