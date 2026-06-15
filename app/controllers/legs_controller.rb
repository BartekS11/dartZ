class LegsController < ApplicationController
  allow_unauthenticated_access

  def checkout
    @leg   = Leg.find(params[:id])
    @match = @leg.match
    @leg.update!(checkout_throws: params[:checkout_throws].presence)

    respond_to do |format|
      format.turbo_stream
      format.html { redirect_to match_path(@match), status: :see_other }
    end
  end
end
