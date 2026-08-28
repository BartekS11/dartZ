module MatchLegManagement
  extend ActiveSupport::Concern

  def winner
    return nil unless finished?
    match_sets.order(:created_at).last
              &.legs&.order(:created_at)&.last
              &.winner
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
        lp.score = starting_score
        lp.starting_score = starting_score if lp.respond_to?(:starting_score=)
        lp.has_doubled_in = !double_in? if lp.respond_to?(:has_doubled_in=)
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
    idx     = ordered.index(player)
    ordered[(idx + 1) % ordered.size]
  end

  def score_for(player)
    return starting_score unless current_leg
    current_leg.leg_players.find_by(player: player)&.score || starting_score
  end

  def subtract_score!(player, points)
    current = score_for(player)
    new_score = current - points

    # Escape on bulk
    return if new_score < 0

    update_score_for(player, new_score)
  end
end
