class Player < ApplicationRecord
  has_many :leg_players, dependent: :destroy
  has_many :turns, dependent: :destroy
  has_many :legs, through: :leg_players
  belongs_to :user, optional: true
  belongs_to :match

  validates :name, presence: true

  def guest?
    user_id.nil?
  end

  def display_name
    guest? ? name : user.email_address
  end
end
