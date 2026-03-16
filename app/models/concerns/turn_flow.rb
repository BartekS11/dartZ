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
    finishing_leg    = match.legs.order(:created_at).last
    finishing_player = finishing_leg.winner

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
    return
  end

  new_turn = match.current_leg.current_turn
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
end
end
