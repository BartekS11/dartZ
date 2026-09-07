module MatchPlayerOrdering
  extend ActiveSupport::Concern

  def players_in_display_order
    ordered_players = players.reorder(:created_at, :id)
    player_display_reversed? ? ordered_players.reverse_order : ordered_players
  end

  def player_display_swappable?
    current_leg.present? && !finished? && players.count == 2
  end

  def player_display_swappable_by?(user:)
    player_display_swappable? && (!invite_match? || invite_host?(user))
  end

  def swap_player_display_order
    with_lock do
      if player_display_swappable?
        update_columns(
          player_display_reversed: !player_display_reversed?,
          updated_at: Time.current
        )
        true
      else
        false
      end
    end
  end
end
