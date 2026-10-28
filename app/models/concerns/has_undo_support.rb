module HasUndoSupport
  extend ActiveSupport::Concern

  def last_turn_with_throws
    current_leg&.turns
               &.joins(:throws)
               &.order("turns.created_at DESC")
               &.first
  end

  def undo_last_throw!(mode: "single")
    with_lock { perform_undo_last_throw!(mode: mode) }
  end

  def perform_undo_last_throw!(mode:)
    return false if finished?

    bot_match = players.exists?(bot: true)
    target_turn = bot_match ? rewind_bot_reply! : last_turn_with_throws
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
    target_turn.update!(total_score: nil) unless target_turn.total_score.nil?
    restore_player_state_for_undo!(target_turn.leg, target_turn.player_id) if bot_match

    true
  end
  private :perform_undo_last_throw!

  private

  def rewind_bot_reply!
    leg = current_leg
    return unless leg

    target = leg.turns.joins(:player, :throws).where(players: { bot: false }).order(id: :desc).first
    return unless target

    replies = leg.turns.where("turns.id > ?", target.id)
    bot_players = replies.joins(:player).where(players: { bot: true }).distinct.pluck(:player_id)
    replies.destroy_all

    bot_players.each { |player_id| restore_player_state_for_undo!(leg, player_id) }
    target
  end

  def restore_player_state_for_undo!(leg, player_id)
    # Replay retained darts with the same per-dart bust handling as ScoringRules.
    # Missed double-ins and busting darts did not reduce the stored score.
    lp = leg.leg_players.find_by!(player_id: player_id)
    score = lp.starting_score
    doubled_in = !double_in?
    leg.turns.where(player_id: player_id).order(:id).includes(:throws).each do |turn|
      turn.throws.sort_by(&:id).each do |dart|
        next unless doubled_in || dart.double?

        doubled_in = true
        remaining = score - dart.points
        break if remaining < 0 || remaining == 1 || (remaining.zero? && double_out? && !dart.double?)

        score = remaining
      end
    end
    lp.update!(score: score, has_doubled_in: doubled_in)
  end

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
