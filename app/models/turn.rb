class Turn < ApplicationRecord
  include HasPublicId
  public_id_prefix "tu_"

  include TurnFlow
  include ScoringRules
  include TurnScoring

  belongs_to :leg
  belongs_to :player
  has_many :throws, dependent: :destroy

  def leg_player
    leg.leg_players.find_by!(player: player)
  end
end
