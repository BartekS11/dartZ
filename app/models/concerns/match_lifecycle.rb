module MatchLifecycle
  extend ActiveSupport::Concern

  def sets_needed_to_win
    (best_of_sets / 2.0).ceil
  end

  def legs_needed_to_win
    (best_of_legs / 2.0).ceil
  end

  def sets_won_by(player)
    match_sets.where(winner_id: player.id).count
  end

  def on_set_finished!(winner)
    if sets_won_by(winner) >= sets_needed_to_win
      finish!(winner)
    else
      start_next_set!
    end
  end

  def start_first_set!
    set = match_sets.create!
    set.start_first_leg!
    set
  end

  def start_next_set!
    set = match_sets.create!
    set.start_first_leg!
    set
  end

  def finish!(winner)
    update!(finished_at: Time.current)
  end

  def finished?
    finished_at.present?
  end

  def current_set
    match_sets.where(finished_at: nil).order(:created_at).last
  end

  def current_leg
    current_set&.current_leg
  end

  def current_player
    current_leg&.current_turn&.player
  end

  def score_for(player)
    return 501 unless current_leg
    current_leg.leg_players.find_by(player: player)&.score || 501
  end
end
