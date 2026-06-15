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
    presenter = MatchStatePresenter.new(match)

    if presenter.finished?
      finishing_leg = match.match_sets.includes(:legs).order(:created_at).last&.legs&.max_by(&:created_at)

      # Web broadcasts
      Turbo::StreamsChannel.broadcast_update_to("match_#{match.id}",
        target: "game-over-section",
        partial: "matches/game_over",
        locals: { match: match, presenter: presenter })
      Turbo::StreamsChannel.broadcast_replace_to("match_#{match.id}",
        target: "finish-popup",
        partial: "matches/finish_popup",
        locals: { player: presenter.winner, leg: finishing_leg })
      Turbo::StreamsChannel.broadcast_update_to("match_#{match.id}",
        target: "score-cards-section", html: "")
      Turbo::StreamsChannel.broadcast_update_to("match_#{match.id}",
        target: "keyboard-section", html: "")
      Turbo::StreamsChannel.broadcast_update_to("match_#{match.id}",
        target: "header-section", html: "")

      # API broadcast for mobile
      ActionCable.server.broadcast("match_#{match.id}_api", presenter.summary_payload.merge(event: "match_finished", winner: presenter.winner&.display_name))

      return
    end

    new_turn = presenter.current_turn

    # Web broadcasts
    Turbo::StreamsChannel.broadcast_update_to("match_#{match.id}",
      target: "current-player",
      partial: "matches/current_player",
      locals: { match: match, presenter: presenter, turn: new_turn })
    Turbo::StreamsChannel.broadcast_replace_to("match_#{match.id}",
      target: "dart-board",
      partial: "matches/dart_board",
      locals: { match: match, turn: new_turn })
    presenter.players.each do |player|
      Turbo::StreamsChannel.broadcast_replace_to("match_#{match.id}",
        target: "score-card-#{player.id}",
        partial: "matches/score_card",
        locals: { match: match, presenter: presenter, player: player })
    end

    # API broadcast for mobile
    ActionCable.server.broadcast("match_#{match.id}_api", presenter.state_payload.merge(event: "turn_changed"))
  end
end
