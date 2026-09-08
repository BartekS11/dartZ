module TurnFlow
  extend ActiveSupport::Concern

  included do
    attr_accessor :voice_announcement_total
    after_update_commit :broadcast_voice_announcement
  end

  def complete_turn!(broadcast: true, voice_total: nil)
    return if completed?
    self.voice_announcement_total = voice_total
    update!(completed_at: Time.current)
    leg.start_next_turn! unless leg.finished?
    broadcast_turn_change! if broadcast
    enqueue_bot_turn_if_needed
  end

  def completed?
    completed_at.present?
  end

  private

  def broadcast_voice_announcement
    return if voice_announcement_total.nil?

    VoiceAnnouncement.broadcast_for(turn: self, total: voice_announcement_total)
    self.voice_announcement_total = nil
  end

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
