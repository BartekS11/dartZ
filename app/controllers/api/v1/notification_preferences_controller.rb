module Api
  module V1
    class NotificationPreferencesController < PushController
      def show
        render json: { data: preference_payload }
      end

      def update
        preference.update!(params.permit(*NotificationPreference::CATEGORIES))
        render json: { data: preference_payload }
      rescue ActiveRecord::RecordInvalid => error
        render_api_error(
          code: "validation_failed",
          message: "Notification preferences are invalid",
          status: :unprocessable_entity,
          details: { errors: error.record.errors.to_hash }
        )
      end

      private

      def preference
        @preference ||= current_api_user.notification_preference || current_api_user.create_notification_preference!
      end

      def preference_payload
        NotificationPreference::CATEGORIES.index_with { |category| preference.public_send(category) }
      end
    end
  end
end
