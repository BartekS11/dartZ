class ThrowsController < ApplicationController
def create
  @turn = Turn.find(params[:turn_id])
  @match = @turn.leg.match
  @throw = @turn.throws.create!(throw_params)
  @turn.apply_throw!(@throw)
  @match.reload

  respond_to do |format|
    format.turbo_stream do
      streams = @match.players.map { |player|
        turbo_stream.update(
          "player-#{player.id}-score",
          html: @match.score_for(player).to_s
        )
      }

      # Update each player panel with fresh throw history
      streams += @match.players.map { |player|
        turbo_stream.replace(
          "player-panel-#{player.id}",
          partial: "matches/player_panel",
          locals: { match: @match, player: player }
        )
      }

      render turbo_stream: streams
    end
    format.html { redirect_to @match }
  end
end

  private

  def throw_params
   params.require(:throw).permit(:segment, :multiplier)
  end
end
