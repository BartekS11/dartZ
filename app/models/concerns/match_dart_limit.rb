module MatchDartLimit
  extend ActiveSupport::Concern

  DART_LIMIT_PER_PLAYER = 1_000

  # Count declared totals as full visits, including zeros and impossible totals.
  # Reopened turns after undo count only their remaining individual records.
  # Query all legs directly so legacy legs without a match set are covered too.
  def safety_darts_for(player, pending_total_turn: nil)
    Turn.joins(:leg).left_joins(:throws)
      .where(legs: { match_id: id }, turns: { player_id: player.id })
      .group("turns.id")
      .pluck("turns.id", "turns.total_score", "turns.completed_at", Arel.sql("COUNT(throws.id)"))
      .sum do |turn_id, total, completed_at, recorded|
        if !total.nil? && (completed_at.present? || turn_id == pending_total_turn&.id)
          3
        else
          recorded
        end
      end
  end

  # Production callers hold the match lock. Check before scoring so a checkout
  # on the limiting submission cannot award a winner or advance a tournament.
  def enforce_dart_limit!(player, pending_total_turn: nil)
    return true if finished?
    return false if safety_darts_for(player, pending_total_turn: pending_total_turn) < DART_LIMIT_PER_PLAYER

    now = Time.current
    all_legs.where(finished_at: nil).find_each do |leg|
      leg.turns.where(completed_at: nil).update_all(completed_at: now)
      leg.update!(finished_at: now, winner_id: nil)
    end
    match_sets.where(finished_at: nil).update_all(finished_at: now, winner_id: nil)
    finish!(nil)
    true
  end
end
