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
      total_points = target_turn.throws.to_a.sum(&:points)
      lp = target_turn.leg.leg_players.find_by(player: target_turn.player)
      lp.update!(score: lp.score + total_points)
      target_turn.throws.destroy_all
    else
      last_throw = target_turn.throws.order(created_at: :desc).first
      return false unless last_throw
      lp = target_turn.leg.leg_players.find_by(player: target_turn.player)
      lp.update!(score: lp.score + last_throw.points)
      last_throw.destroy!
    end

    if target_turn.completed?
      current.destroy! if current && current != target_turn && current.throws.empty?
      target_turn.update!(completed_at: nil)
    end

    true
  end
end
