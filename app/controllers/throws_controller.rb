class ThrowsController < ApplicationController
  allow_unauthenticated_access
  before_action :resume_session_optional

  def create
    @turn  = Turn.find(params[:turn_id])
    @match = @turn.leg.match
    authorize_match!(@match)
    return if performed?

    @match = ThrowSubmission.call(
      turn: @turn,
      total: params[:throw][:total],
      throw_attributes: throw_params
    )

    respond_to do |format|
      format.turbo_stream { render_streams }
      format.html         { redirect_to @match }
    end
  end

  def undo
    @turn  = Turn.find(params[:turn_id])
    @match = @turn.leg.match
    authorize_match!(@match)
    return if performed?

    mode   = request.headers["X-Undo-Mode"] || "total"

    @match.with_lock do
      @match.undo_last_throw!(mode: mode)
      @match.reload
    end

    respond_to do |format|
      format.turbo_stream { render_streams }
      format.html         { redirect_to @match }
    end
  end

  private

  def render_streams
    presenter = MatchStatePresenter.new(@match)
    current_turn = presenter.finished? ? nil : presenter.current_turn

    streams = presenter.players.map do |player|
      turbo_stream.replace("score-card-#{player.id}",
        partial: "matches/score_card",
        locals:  { match: @match, presenter: presenter, player: player })
    end

    if current_turn
      streams << turbo_stream.update("current-player",
        partial: "matches/current_player",
        locals:  { match: @match, presenter: presenter, turn: current_turn })
      streams << turbo_stream.replace("dart-board",
        partial: "matches/dart_board",
        locals:  { match: @match, turn: current_turn })
    elsif presenter.finished?
      finishing_leg = @match.match_sets.includes(:legs).order(:created_at).last&.legs&.max_by(&:created_at)

      streams << turbo_stream.update("game-over-section",
        partial: "matches/game_over",
        locals:  { match: @match, presenter: presenter })
      streams << turbo_stream.replace("finish-popup",
        partial: "matches/finish_popup",
        locals:  { player: presenter.winner, leg: finishing_leg })
      streams << turbo_stream.update("score-cards-section", html: "")
      streams << turbo_stream.update("keyboard-section",    html: "")
      streams << turbo_stream.update("header-section",      html: "")
    end

    broadcast_tournament_update!

    render turbo_stream: streams
  end

  def broadcast_tournament_update!
    tournament_match = TournamentMatch.find_by(linked_match: @match)
    return unless tournament_match

    tournament = tournament_match.tournament
    tournament.sync_from_linked_matches! if @match.finished?
    tournament.broadcast_live_update!
  end

  def throw_params
    params.require(:throw).permit(:segment, :multiplier)
  end
end
