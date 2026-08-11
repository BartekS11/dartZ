class ProfilesController < ApplicationController
  before_action :require_authentication

  def update
    Current.user.update!(profile_params)
    redirect_back fallback_location: matches_path, notice: t("flashes.profile_updated")
  end

  private

  def profile_params
    params.require(:user).permit(:nickname)
  end
end
