class Friendship < ApplicationRecord
  include HasPublicId
  public_id_prefix "fr_"

  belongs_to :user_low, class_name: "User"
  belongs_to :user_high, class_name: "User"

  validates :user_low_id, comparison: { less_than: :user_high_id }, uniqueness: { scope: :user_high_id }

  scope :for_user, ->(user) { where(user_low: user).or(where(user_high: user)) }

  def self.between(user_a, user_b)
    low_id, high_id = [ user_a.id, user_b.id ].sort
    find_by(user_low_id: low_id, user_high_id: high_id)
  end

  def self.create_between!(user_a, user_b)
    low, high = [ user_a, user_b ].sort_by(&:id)
    create!(user_low: low, user_high: high)
  end

  def other_user(user)
    user_low_id == user.id ? user_high : user_low
  end
end
