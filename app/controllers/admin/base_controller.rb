module Admin
  class BaseController < ActionController::Base
    layout "admin"
    protect_from_forgery with: :exception

    before_action :prevent_admin_indexing
    before_action :require_admin_authentication

    helper_method :current_admin_user

    private

    def current_admin_user
      Current.admin_user
    end

    def require_admin_authentication
      session = find_admin_session
      return not_found unless session

      Current.admin_session = session
    end

    def find_admin_session
      id = cookies.signed[:admin_session_id]
      return if id.blank?

      session = AdminSession.find_by(id: id)
      if session&.expired?
        session.destroy!
        cookies.delete(:admin_session_id)
        return
      end
      session
    end

    def start_admin_session!(admin_user)
      admin_session = admin_user.admin_sessions.create!(
        ip_address: request.remote_ip,
        user_agent: request.user_agent,
        expires_at: AdminSession::LIFETIME.from_now
      )
      Current.admin_session = admin_session
      cookies.signed[:admin_session_id] = {
        value: admin_session.id,
        expires: admin_session.expires_at,
        httponly: true,
        same_site: :strict,
        secure: Rails.env.production?
      }
    end

    def terminate_admin_session!
      Current.admin_session&.destroy!
      cookies.delete(:admin_session_id)
      Current.admin_session = nil
    end

    def prevent_admin_indexing
      response.headers["X-Robots-Tag"] = "noindex, nofollow, noarchive"
      response.headers["Cache-Control"] = "no-store, private"
    end

    def not_found
      head :not_found
    end
  end
end
