class LegsController < ApplicationController
  allow_unauthenticated_access

  def checkout
    @leg   = Leg.find(params[:id])
    @match = @leg.match
    @leg.update!(checkout_throws: params[:checkout_throws].presence)

    redirect_to match_path(@match), status: :see_other
  end
end
