module LegFlow
  extend ActiveSupport::Concern

  def current_turn
    turns.order(:created_at).last
  end

  def ensure_turn!
    return current_turn if current_turn && !current_turn.completed?

    advance_turn!
  end

  def advance_turn!
    next_player = next_player_after(current_turn&.player)
    turns.create!(player: next_player)
  end

  def finish!(winner)
    update!(
      finished_at: Time.current,
      winner_id: winner.id
    )
    match.finish!(winner)
  end

  private

  def next_player_after(player)
    players = leg_players.includes(:player).map(&:player)
    return players.first if player.nil?

    players[(players.index(player) + 1) % players.size]
  end
end
