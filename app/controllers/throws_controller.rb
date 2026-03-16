class ThrowsController < ApplicationController
  skip_before_action :require_authentication

  def create
    @turn  = Turn.find(params[:turn_id])
    @match = @turn.leg.match

    if params[:throw][:total].present?
      @turn.distribute_total!(params[:throw][:total].to_i)
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
    mode   = request.headers["X-Undo-Mode"] || "single"

    @match.undo_last_throw!(mode: mode)
    @match.reload

    respond_to do |format|
      format.turbo_stream { render_streams }
      format.html         { redirect_to @match }
    end
  end

  private

  def render_streams
    @match.reload
    current_turn = @match.finished? ? nil : @match.current_leg&.current_turn

    streams = @match.players.flat_map { |p|
      [
        turbo_stream.replace("score-card-#{p.id}",
          partial: "matches/score_card",
          locals:  { match: @match, player: p })
      ]
    }

    if current_turn
      streams << turbo_stream.update("current-player",
        partial: "matches/current_player",
        locals:  { match: @match, turn: current_turn })
      streams << turbo_stream.replace("dart-board",
        partial: "matches/dart_board",
        locals:  { match: @match, turn: current_turn })
    elsif @match.finished?
      finishing_leg    = @match.legs.order(:created_at).last
      finishing_player = finishing_leg.winner

      streams << turbo_stream.update("game-over-section",
        partial: "matches/game_over",
        locals:  { match: @match })
      streams << turbo_stream.replace("finish-popup",
        partial: "matches/finish_popup",
        locals:  { player: finishing_player, leg: finishing_leg })
      streams << turbo_stream.update("score-cards-section", html: "")
      streams << turbo_stream.update("keyboard-section",    html: "")
    end

    render turbo_stream: streams
  end

  def throw_params
    params.require(:throw).permit(:segment, :multiplier)
  end
end
