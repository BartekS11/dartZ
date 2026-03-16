class LegsController < ApplicationController
  skip_before_action :require_authentication

  def checkout
    @leg   = Leg.find(params[:id])
    @match = @leg.match
    @leg.update!(checkout_throws: params[:checkout_throws].presence)
    @match.reload

    respond_to do |format|
      format.turbo_stream {
        streams = [ turbo_stream.update("finish-popup", html: "") ]
        if @match.finished?
          streams << turbo_stream.update("game-over-section",
            partial: "matches/game_over",
            locals:  { match: @match })
        end
        render turbo_stream: streams
      }
      format.html { redirect_to @match }
    end
  end
end
