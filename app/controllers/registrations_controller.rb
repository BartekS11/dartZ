class RegistrationsController < ApplicationController
  allow_unauthenticated_access only: %i[new create]
  rate_limit to: 5, within: 3.minutes, only: :create, with: -> { redirect_to new_registration_path, alert: "Try again later." }

  def new
    @user = User.new
  end

  def create
    @user = User.new(registration_params)
    @user.account_tier = "free"

    if @user.save
      start_new_session_for @user
      redirect_to matches_path, notice: "Account created."
    else
      flash.now[:alert] = "Please fix the highlighted fields."
      render :new, status: :unprocessable_entity
    end
  end

  private

  def registration_params
    params.require(:user).permit(:email_address, :nickname, :password, :password_confirmation)
  end
end
