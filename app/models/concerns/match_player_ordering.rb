module MatchPlayerOrdering
  extend ActiveSupport::Concern

  def players_in_display_order
    ordered_players = players.reorder(:created_at, :id)
    player_display_reversed? ? ordered_players.reverse_order : ordered_players
  end

  def player_thrower_swap_context?
    current_leg&.current_turn.present? && !finished? && players.count == 2
  end

  def player_thrower_swappable?
    return false unless player_thrower_swap_context?

    turn = current_leg.current_turn
    turn.present? && current_leg.turns.count <= 3 && turn.throws.none? && turn.total_score.nil?
  end

  def player_thrower_swap_visible_by?(user:)
    player_thrower_swap_context? && (!invite_match? || invite_host?(user))
  end

  def swap_current_thrower
    swapped_turn = nil

    with_lock do
      next unless player_thrower_swappable?

      turn = current_leg.current_turn
      other_player = players.where.not(id: turn.player_id).first
      next unless other_player

      turn.update!(player: other_player)
      swapped_turn = turn
    end

    BotTurnJob.perform_later(swapped_turn.id) if swapped_turn&.player&.bot?
    swapped_turn.present?
  end
end
