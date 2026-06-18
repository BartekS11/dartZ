module HasUndoSupport
  extend ActiveSupport::Concern

  def last_turn_with_throws
    current_leg&.turns
               &.joins(:throws)
               &.order("turns.created_at DESC")
               &.first
  end

  def undo_last_throw!(mode: "single")
    target_turn = last_turn_with_throws
    return false unless target_turn

    current = current_leg.current_turn

    if mode == "total"
      lp = target_turn.leg.leg_players.find_by(player: target_turn.player)
      removed_throws = target_turn.throws.to_a
      total_points = scoring_points_for_undo(lp, target_turn, removed_throws)
      attrs = { score: lp.score + total_points }
      attrs[:has_doubled_in] = false if target_turn.leg.match.double_in? && removed_opening_double?(target_turn, removed_throws)
      lp.update!(attrs)
      target_turn.throws.destroy_all
    else
      last_throw = target_turn.throws.order(created_at: :desc).first
      return false unless last_throw
      lp = target_turn.leg.leg_players.find_by(player: target_turn.player)
      attrs = { score: lp.score + scoring_points_for_undo(lp, target_turn, [ last_throw ]) }
      attrs[:has_doubled_in] = false if target_turn.leg.match.double_in? && removed_opening_double?(target_turn, [ last_throw ])
      lp.update!(attrs)
      last_throw.destroy!
    end

    if target_turn.completed?
      current.destroy! if current && current != target_turn && current.throws.empty?
      target_turn.update!(completed_at: nil)
    end

    true
  end

  private

  def scoring_points_for_undo(leg_player, turn, removed_throws)
    return removed_throws.sum(&:points) unless leg_player.leg.match.double_in?

    prior_open = prior_double_before?(turn, removed_throws.map(&:created_at).min, excluded_ids: removed_throws.map(&:id))
    scoring = prior_open
    removed_throws.sort_by(&:created_at).sum do |throw|
      if scoring || throw.double?
        scoring = true
        throw.points
      else
        0
      end
    end
  end

  def removed_opening_double?(turn, removed_throws)
    return false unless removed_throws.any?(&:double?)

    removed_ids = removed_throws.map(&:id)
    !prior_double_before?(turn, removed_throws.map(&:created_at).min, excluded_ids: removed_ids)
  end

  def prior_double_before?(turn, timestamp, excluded_ids: [])
    turn.leg.turns.includes(:throws).order(:created_at).any? do |candidate_turn|
      next false unless candidate_turn.player_id == turn.player_id
      next false if candidate_turn.created_at > turn.created_at

      candidate_turn.throws.any? do |throw|
        !excluded_ids.include?(throw.id) && throw.double? && throw.created_at < timestamp
      end
    end
  end
end
