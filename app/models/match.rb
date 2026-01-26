class Match < ApplicationRecord
  include MatchLifecycle

  has_many :players, dependent: :destroy
  has_many :legs, dependent: :destroy

  def winner
    return nil unless finished?

    legs.last
        .leg_players
        .find { |lp| lp.score == 0 }
        &.player
  end

  def ensure_current_leg!
    leg = legs.order(:created_at).last
    return leg if leg.present? && !leg.finished?

    start_first_leg!
  end


  def start_first_leg!
    leg = legs.create!

    players.each do |player|
      leg.leg_players.find_or_create_by!(
        player: player
      ) do |lp|
        lp.score = 501
      end
    end

    leg.start_first_turn!
    leg
  end
  def current_leg
    legs.where(finished_at: nil).order(:created_at).last
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
