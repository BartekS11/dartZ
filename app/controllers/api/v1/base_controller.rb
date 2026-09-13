module Api
  module V1
    class BaseController < ActionController::API
      include ExceptionHandler

      before_action :ensure_api_v1_enabled!
      before_action :authenticate_api_user!

      rescue_from Api::V1::RequestParameters::InvalidParameter, with: :render_invalid_parameter

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

      def current_guest_id
        @guest_id
      end

      def guest_session?
        @api_user.nil? && @guest_id.present?
      end

      def authorize_api_match!(match)
        return if MatchAccess.new(match: match, user: current_api_user, guest_id: current_guest_id).allowed?

        raise ExceptionHandler::Unauthorized, "Forbidden"
      end

      # Helpers below establish the contract for roadmap endpoints. Existing API
      # endpoints intentionally keep their current unwrapped response shapes.
      def paginate(scope, default_per_page: Api::V1::RequestParameters::DEFAULT_PER_PAGE)
        pagination = request_parameters.pagination(default_per_page: default_per_page)
        count = scope.except(:limit, :offset, :order).count
        total_count = count.is_a?(Hash) ? count.length : count

        [
          scope.limit(pagination.per_page).offset(pagination.offset),
          pagination.metadata(total_count: total_count)
        ]
      end

      def paginate_array(items, default_per_page: Api::V1::RequestParameters::DEFAULT_PER_PAGE)
        pagination = request_parameters.pagination(default_per_page: default_per_page)
        [
          items.slice(pagination.offset, pagination.per_page) || [],
          pagination.metadata(total_count: items.size)
        ]
      end

      def api_date_range
        request_parameters.date_range
      end

      def require_api_roadmap_feature!(feature)
        unless FeatureAccess.enabled?(feature)
          return render_api_error(
            code: "feature_unavailable",
            message: "Feature is unavailable",
            status: :not_found
          )
        end
        return if FeatureAccess.entitled?(feature, user: current_api_user)

        render_api_error(
          code: "feature_forbidden",
          message: "Your account does not have access to this feature",
          status: :forbidden
        )
      end

      def render_invalid_parameter(exception)
        render_api_error(
          code: "invalid_parameter",
          message: exception.message,
          status: :unprocessable_entity,
          details: { parameter: exception.parameter }
        )
      end

      def render_api_error(code:, message:, status:, details: nil)
        error = { code: code, message: message }
        error[:details] = details if details.present?
        render json: { error: error }, status: status
      end

      def request_parameters
        @request_parameters ||= Api::V1::RequestParameters.new(params)
      end
    end
  end
end
