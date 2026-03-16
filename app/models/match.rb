class Match < ApplicationRecord
  include MatchLifecycle
  include HasThrowHistory
  include HasUndoSupport

  has_many :players,  dependent: :destroy
  has_many :match_sets, dependent: :destroy, class_name: "MatchSet"
  has_many :legs,     through: :match_sets
  has_many :turns,    through: :legs
  has_many :throws,   through: :turns

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
    idx     = ordered.index(player)
    ordered[(idx + 1) % ordered.size]
  end

  def score_for(player)
    return 501 unless current_leg
    current_leg.leg_players.find_by(player: player)&.score || 501
  end

  def subtract_score!(player, points)
    current = score_for(player)
    new_score = current - points

    # Escape on bulk
    return if new_score < 0

    update_score_for(player, new_score)
  end
end
