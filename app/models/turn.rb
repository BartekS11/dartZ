class Turn < ApplicationRecord
  include TurnFlow
  include ScoringRules

  belongs_to :leg
  belongs_to :player
  has_many :throws, dependent: :destroy

  def leg_player
    leg.leg_players.find_by!(player: player)
  end
end
