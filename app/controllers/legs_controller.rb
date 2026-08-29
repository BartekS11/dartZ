class LegsController < ApplicationController
  allow_unauthenticated_access
  before_action :resume_session_optional

  def checkout
    @leg   = Leg.find_by_public_id!(params[:id])
    @match = @leg.match
    authorize_match!(@match)
    return if performed?

    @match.with_lock do
      @leg.update!(checkout_throws: params[:checkout_throws].presence)
    end

    respond_to do |format|
      format.turbo_stream
      format.html { redirect_to match_path(@match), status: :see_other }
    end
  end
end
