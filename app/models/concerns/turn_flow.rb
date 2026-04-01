module TurnFlow
  extend ActiveSupport::Concern

  def complete_turn!(broadcast: true)
    return if completed?
    update!(completed_at: Time.current)
    leg.start_next_turn! unless leg.finished?
    broadcast_turn_change! if broadcast
    enqueue_bot_turn_if_needed
  end

  def completed?
    completed_at.present?
  end

  private

  def enqueue_bot_turn_if_needed
    return if leg.finished?
    next_turn = leg.current_turn
    return unless next_turn&.player&.bot?
    BotTurnJob.perform_later(next_turn.id)
  end

  def broadcast_turn_change!
    match = leg.match
    match.reload

    if match.finished?
      finishing_leg    = match.legs.order(:created_at).last
      finishing_player = finishing_leg.winner

      # Web broadcasts
      Turbo::StreamsChannel.broadcast_update_to("match_#{match.id}",
        target: "game-over-section",
        partial: "matches/game_over",
        locals: { match: match })
      Turbo::StreamsChannel.broadcast_replace_to("match_#{match.id}",
        target: "finish-popup",
        partial: "matches/finish_popup",
        locals: { player: finishing_player, leg: finishing_leg })
      Turbo::StreamsChannel.broadcast_update_to("match_#{match.id}",
        target: "score-cards-section", html: "")
      Turbo::StreamsChannel.broadcast_update_to("match_#{match.id}",
        target: "keyboard-section", html: "")
      Turbo::StreamsChannel.broadcast_update_to("match_#{match.id}",
        target: "header-section", html: "")

      # API broadcast for mobile
      ActionCable.server.broadcast("match_#{match.id}_api", {
        event:  "match_finished",
        winner: match.winner&.display_name,
        players: match.players.map { |p|
          {
            id:     p.id,
            name:   p.display_name,
            score:  match.score_for(p),
            avg:    match.three_dart_average(p),
            winner: match.winner == p
          }
        }
      })

      return
    end

    new_turn = match.current_leg.current_turn

    # Web broadcasts
    Turbo::StreamsChannel.broadcast_update_to("match_#{match.id}",
      target: "current-player",
      partial: "matches/current_player",
      locals: { match: match, turn: new_turn })
    Turbo::StreamsChannel.broadcast_replace_to("match_#{match.id}",
      target: "dart-board",
      partial: "matches/dart_board",
      locals: { match: match, turn: new_turn })
    match.players.each do |player|
      Turbo::StreamsChannel.broadcast_replace_to("match_#{match.id}",
        target: "score-card-#{player.id}",
        partial: "matches/score_card",
        locals: { match: match, player: player })
    end

    # API broadcast for mobile
    ActionCable.server.broadcast("match_#{match.id}_api", {
      event:           "turn_changed",
      current_player:  match.current_player&.display_name,
      current_turn_id: new_turn&.id,
      players:         match.players.map { |p|
        {
          id:       p.id,
          name:     p.display_name,
          score:    match.score_for(p),
          avg:      match.three_dart_average(p),
          sets_won: match.sets_won_by(p),
          legs_won: match.current_set&.legs_won_by(p) || 0,
          checkout: CheckoutCalculator.suggest(match.score_for(p))
        }
      }
    })
  end
end
