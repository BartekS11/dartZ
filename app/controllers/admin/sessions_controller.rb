module Admin
  class SessionsController < BaseController
    skip_before_action :require_admin_authentication, only: %i[new create]
    rate_limit to: 5, within: 5.minutes, only: :create,
      with: -> { redirect_to admin_login_path, alert: "Try again later." }

    def new
      redirect_to admin_root_path if find_admin_session
    end

    def create
      AdminSession.where(expires_at: ..Time.current).delete_all
      admin_user = AdminUser.authenticate_by(params.permit(:email_address, :password))
      if admin_user
        start_admin_session!(admin_user)
        redirect_to admin_root_path
      else
        redirect_to admin_login_path, alert: "Invalid credentials."
      end
    end

    def destroy
      terminate_admin_session!
      redirect_to admin_login_path, status: :see_other
    end
  end
end
