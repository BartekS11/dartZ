class ThrowsController < ApplicationController
  allow_unauthenticated_access
  before_action :resume_session_optional

  def create
    @turn  = Turn.find(params[:turn_id])
    @match = @turn.leg.match
    authorize_match!(@match)
    return if performed?
    return unless authorize_remote_turn!(@match, @turn.player)

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

    last_throw_player = @match.throws.order(created_at: :desc).first&.turn&.player || @turn.player
    return unless authorize_remote_turn!(@match, last_throw_player)

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

  def authorize_remote_turn!(match, player)
    return true unless match.invite_match?

    actor_player_id = params[:actor_player_id].presence || request.headers["X-Actor-Player-Id"].presence
    local_player = actor_player_id.present? ? match.players.find_by(id: actor_player_id) : current_match_player(match)
    return true if local_player&.id == player.id

    respond_to do |format|
      format.turbo_stream { head :conflict }
      format.html { redirect_to match_path(match), alert: "Waiting for the other player." }
      format.json { render json: { error: "Not your turn" }, status: :conflict }
    end
    false
  end

  def render_streams
    presenter = MatchStatePresenter.new(@match)
    current_turn = presenter.finished? ? nil : presenter.current_turn
    match_player = current_match_player

    streams = presenter.players.map do |player|
      turbo_stream.replace(
        "score-card-#{player.id}",
        partial: "matches/score_card",
        locals: {
          match: @match,
          presenter: presenter,
          player: player
        }
      )
    end

    if current_turn
      streams << turbo_stream.update(
        "current-player",
        partial: "matches/current_player",
        locals: {
          match: @match,
          presenter: presenter,
          turn: current_turn,
          current_match_player: match_player
        }
      )

      streams << turbo_stream.replace(
        "dart-board",
        partial: "matches/dart_board",
        locals: {
          match: @match,
          turn: current_turn
        }
      )

    elsif presenter.finished?

      finishing_leg = @match
        .match_sets
        .includes(:legs)
        .order(:created_at)
        .last
        &.legs
        &.max_by(&:created_at)

      streams << turbo_stream.update(
        "game-over-section",
        partial: "matches/game_over",
        locals: {
          match: @match,
          presenter: presenter
        }
      )

      streams << turbo_stream.replace(
        "finish-popup",
        partial: "matches/finish_popup",
        locals: {
          player: presenter.winner,
          leg: finishing_leg
        }
      )

      streams << turbo_stream.update(
        "score-cards-section",
        html: ""
      )

      streams << turbo_stream.update(
        "keyboard-section",
        html: ""
      )

      streams << turbo_stream.update(
        "header-section",
        html: ""
      )
    end

    broadcast_match_update!(streams)
    broadcast_tournament_update!

    render turbo_stream: streams
  end

  def broadcast_match_update!(streams)
    Turbo::StreamsChannel.broadcast_stream_to(
      "match_#{@match.id}",
      content: streams.map(&:to_s).join
    )
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

  def current_match_player(match = @match)
    return nil unless params[:actor_player_id].present?

    match.players.find_by(id: params[:actor_player_id])
  end
end
