module Api
  module V1
    class SocialController < BaseController
      before_action -> { require_api_roadmap_feature!(:friends) }

      rescue_from Social::Error, with: :render_social_error
      rescue_from ActiveRecord::RecordNotFound, with: :render_social_not_found

      private

      def render_social_error(error)
        render_api_error(code: error.code, message: error.message, status: error.status, details: error.details)
      end

      def render_social_not_found(_error)
        render_api_error(code: "not_found", message: "Resource is unavailable", status: :not_found)
      end

      def find_target
        if params[:user_id].present?
          User.find_by_public_id!(params[:user_id])
        elsif params[:share_code].present?
          User.find_by!(friend_share_code: normalized_share_code)
        else
          raise Social::Error.new("user_id or share_code is required", details: { field: "user_id" })
        end
      end

      def normalized_share_code
        params[:share_code].to_s.delete("- ").upcase
      end

      def serializer_for(users)
        Api::V1::SocialSerializer.new(viewer: current_api_user, users: users)
      end
    end
  end
end
