class RegistrationsController < ApplicationController
  allow_unauthenticated_access only: %i[new create]
  rate_limit to: 5, within: 3.minutes, only: :create, with: -> { redirect_to new_registration_path, alert: t("flashes.try_again_later") }

  def new
    @user = User.new
  end

  def create
    @user = User.new(registration_params)
    @user.account_tier = "free"
    @user.locale = I18n.locale.to_s

    if @user.save
      start_new_session_for @user
      redirect_to matches_path, notice: t("flashes.account_created")
    else
      flash.now[:alert] = t("flashes.fix_fields")
      render :new, status: :unprocessable_entity
    end
  end

  private

  def registration_params
    params.require(:user).permit(:email_address, :nickname, :password, :password_confirmation)
  end
end
