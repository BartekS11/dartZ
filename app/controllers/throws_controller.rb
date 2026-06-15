class ThrowsController < ApplicationController
  allow_unauthenticated_access

  def create
    @turn  = Turn.find(params[:turn_id])
    @match = @turn.leg.match

    if params[:throw][:total].present?
      total           = params[:throw][:total].to_i
      darts_remaining = 3 - @turn.throws.count
      max_possible    = darts_remaining * 60

      @turn.update!(total_score: total)

      if total > max_possible || total > @match.score_for(@turn.player)
        @turn.complete_turn!(broadcast: false)
      else
        @turn.distribute_total!(total)
      end
    else
      @throw = @turn.throws.create!(throw_params)
      @turn.apply_throw!(@throw)
    end

    @match.reload

    respond_to do |format|
      format.turbo_stream { render_streams }
      format.html         { redirect_to @match }
    end
  end

  def undo
    @turn  = Turn.find(params[:turn_id])
    @match = @turn.leg.match
    mode   = request.headers["X-Undo-Mode"] || "total"

    @match.undo_last_throw!(mode: mode)
    @match.reload

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

    render turbo_stream: streams
  end

  def throw_params
    params.require(:throw).permit(:segment, :multiplier)
  end
end
