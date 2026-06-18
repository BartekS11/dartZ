class Player < ApplicationRecord
  has_many :leg_players, dependent: :destroy
  has_many :turns, dependent: :destroy
  has_many :legs, through: :leg_players

  belongs_to :user, optional: true
  belongs_to :match

  validates :name, presence: true, length: { maximum: 20 }
  validates :bot_level, numericality: { only_integer: true, greater_than_or_equal_to: 1, less_than_or_equal_to: 20 }, allow_nil: true

  def bot?
    bot == true
  end

  def guest?
    user_id.nil? && !bot?
  end

  def display_name
    return name if bot? || guest?
    user.display_name
  end
end
