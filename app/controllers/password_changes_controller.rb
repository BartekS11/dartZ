class PasswordChangesController < ApplicationController
  before_action :prevent_caching

  def edit
  end

  def update
    user = Current.user
    password = params[:password].to_s
    confirmation = params[:password_confirmation].to_s

    if password.length < 12 || password != confirmation || user.authenticate(password)
      flash.now[:alert] = t("password_change.invalid")
      render :edit, status: :unprocessable_entity
      return
    end

    user.with_lock do
      user.update!(password: password, password_confirmation: confirmation, password_change_required: false)
      user.sessions.destroy_all
    end
    start_new_session_for(user)
    redirect_to after_authentication_url, notice: t("flashes.password_reset")
  rescue ActiveRecord::RecordInvalid
    flash.now[:alert] = t("password_change.invalid")
    render :edit, status: :unprocessable_entity
  end

  private

  def prevent_caching
    response.headers["Cache-Control"] = "no-store, private"
  end
end
