class LegsController < ApplicationController
  skip_before_action :require_authentication

  def checkout
    @leg   = Leg.find(params[:id])
    @match = @leg.match

    @leg.update!(checkout_throws: params[:checkout_throws].presence)

    respond_to do |format|
      format.turbo_stream {
        render turbo_stream: turbo_stream.update("finish-popup", html: "")
      }
      format.html { redirect_to @match }
    end
  end
end
