module Api
  module V1
    class BaseController < ActionController::API
      include ExceptionHandler

      before_action :ensure_api_v1_enabled!
      before_action :authenticate_api_user!

      private

      def ensure_api_v1_enabled!
        return if Rails.configuration.x.api_v1_enabled

        render json: { error: "API v1 is disabled" }, status: :service_unavailable
      end

      def authenticate_api_user!
        header    = request.headers["Authorization"]
        token     = header&.split(" ")&.last
        raise ExceptionHandler::MissingToken, "Missing token" unless token

        decoded   = JsonWebToken.decode(token)
        @api_user = decoded[:guest] ? nil : User.find(decoded[:user_id])
        @guest_id = decoded[:guest_id] if decoded[:guest]
      rescue ActiveRecord::RecordNotFound
        raise ExceptionHandler::InvalidToken, "Invalid token"
      end

      def current_api_user
        @api_user
      end

      def guest_session?
        @api_user.nil? && @guest_id.present?
      end
    end
  end
end
