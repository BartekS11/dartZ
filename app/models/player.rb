class Player < ApplicationRecord
  has_many :leg_players, dependent: :destroy
  has_many :turns, dependent: :destroy
  has_many :legs, through: :leg_players

  belongs_to :user, optional: true
  belongs_to :match

  validates :name, presence: true

  def bot?
    bot == true
  end

  def guest?
    user_id.nil? && !bot?
  end

  def display_name
    return name if bot? || guest?
    user.email_address
  end
end
