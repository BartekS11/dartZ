module Api
  module V1
    class UsersController < SocialController
      rate_limit to: 30, within: 1.hour, only: :search, by: -> { current_api_user&.id || request.remote_ip },
        with: -> { render_rate_limited }

      def search
        query = params[:nickname].presence || params[:share_code]
        raise Social::Error.new("nickname or share_code is required", details: { parameter: "nickname" }) if query.blank?

        users = Social::UserDiscovery.call(viewer: current_api_user, query: query)
        records, pagination = paginate(users)
        serializer = serializer_for(records)
        render json: { data: records.map { |user| serializer.user(user) }, pagination: pagination }
      end

      private

      def render_rate_limited
        response.set_header("Retry-After", "3600")
        render_api_error(code: "rate_limited", message: "Too many searches", status: :too_many_requests)
      end
    end
  end
end
