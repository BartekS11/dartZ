module Api
  module V1
    class FriendSettingsController < SocialController
      def show
        render json: { data: settings }
      end

      def update
        current_api_user.update!(settings_params)
        render json: { data: settings }
      rescue ActiveRecord::RecordInvalid => error
        render_api_error(
          code: "validation_failed",
          message: "Settings are invalid",
          status: :unprocessable_entity,
          details: { errors: error.record.errors.to_hash }
        )
      end

      private

      def settings
        {
          share_code: current_api_user.friend_share_code,
          discoverable_by_nickname: current_api_user.discoverable_by_nickname,
          friend_request_policy: current_api_user.friend_request_policy,
          challenge_policy: current_api_user.challenge_policy
        }
      end

      def settings_params
        params.permit(:discoverable_by_nickname, :friend_request_policy, :challenge_policy)
      end
    end
  end
end
