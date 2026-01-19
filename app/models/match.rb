
class Match < ApplicationRecord
  has_many :players, dependent: :destroy
  has_many :legs, dependent: :destroy

  def start_first_leg!
    leg = legs.create!
    leg.turns.create!(player: players.first)
  end

  def current_leg
    legs.where(finished_at: nil).order(:created_at).last
  end

  def finished?
    legs.exists? && legs.all?(&:finished_at)
  end

  def current_player
    current_leg&.current_turn&.player
  end

  def next_player_after(player)
    ordered = players.order(:created_at).to_a
    idx = ordered.index(player)
    ordered[(idx + 1) % ordered.size]
  end

  def score_for(player)
    return 501 unless current_leg
    current_leg.leg_players.find_by(player: player)&.score || 501
  end
end

