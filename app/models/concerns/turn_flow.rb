module TurnFlow
  extend ActiveSupport::Concern

  def complete_turn!(broadcast: true)
    return if completed?
    update!(completed_at: Time.current)
    leg.start_next_turn!
    broadcast_turn_change! if broadcast
  end

  def completed?
    completed_at.present?
  end

  private

  def broadcast_turn_change!
    match = leg.match
    match.reload

    if match.finished?
      Turbo::StreamsChannel.broadcast_replace_to(
        "match_#{match.id}",
        target: "match",
        partial: "matches/game_over",
        locals: { match: match }
      )

      # Clear the keyboard and dart board
      Turbo::StreamsChannel.broadcast_remove_to(
        "match_#{match.id}",
        target: "current-player"
      )
      Turbo::StreamsChannel.broadcast_remove_to(
        "match_#{match.id}",
        target: "dart-board"
      )
      return
    end

    new_turn = match.current_leg.current_turn

    Turbo::StreamsChannel.broadcast_update_to(
      "match_#{match.id}",
      target: "current-player",
      partial: "matches/current_player",
      locals: { match: match, turn: new_turn }
    )

    Turbo::StreamsChannel.broadcast_replace_to(
      "match_#{match.id}",
      target: "dart-board",
      partial: "matches/dart_board",
      locals: { match: match, turn: new_turn }
    )

    Turbo::StreamsChannel.broadcast_update_to(
      "match_#{match.id}",
      target: "current-player",
      partial: "matches/current_player",
      locals: { match: match, turn: new_turn }
    )

    match.players.each do |player|
      Turbo::StreamsChannel.broadcast_replace_to(
        "match_#{match.id}",
        target: "score-card-#{player.id}",
        partial: "matches/score_card",
        locals: { match: match, player: player }
      )
    end
  end
end
