module Api
  module V1
    class PushController < BaseController
      before_action -> { require_api_roadmap_feature!(:web_push) }

      rescue_from ActiveRecord::RecordNotFound do
        render_api_error(code: "not_found", message: "Resource is unavailable", status: :not_found)
      end

      private

      def serialize_subscription(subscription)
        {
          id: subscription.public_id,
          device_label: subscription.device_label,
          created_at: subscription.created_at.iso8601,
          last_success_at: subscription.last_success_at&.iso8601,
          last_failure_at: subscription.last_failure_at&.iso8601
        }
      end
    end
  end
end
