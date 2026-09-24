module Api
  module V1
    class PushSubscriptionsController < PushController
      rate_limit to: 10, within: 1.hour, only: :test, by: -> { current_api_user&.id || request.remote_ip },
        with: -> { render_rate_limited }

      def index
        records = current_api_user.push_subscriptions.active.order(created_at: :desc, public_id: :desc)
        subscriptions, pagination = paginate(records)
        render json: { data: subscriptions.map { |subscription| serialize_subscription(subscription) }, pagination: pagination }
      end

      def create
        subscription = PushNotifications::SubscriptionRegistrar.call(
          user: current_api_user,
          endpoint: params[:endpoint],
          p256dh: params.dig(:keys, :p256dh),
          auth: params.dig(:keys, :auth),
          device_label: params[:device_label]
        )
        render json: { data: serialize_subscription(subscription) }, status: :created
      rescue ActiveRecord::RecordInvalid => error
        render_api_error(
          code: "validation_failed",
          message: "Push subscription is invalid",
          status: :unprocessable_entity,
          details: { errors: error.record.errors.to_hash }
        )
      end

      def destroy
        subscription = current_api_user.push_subscriptions.find_by!(public_id: params[:id])
        subscription.revoke!(error_code: "user_removed")
        head :no_content
      end

      def test
        deliveries = PushNotifications::Notifier.test(current_api_user)
        if deliveries.any?
          render json: { data: { queued: true } }, status: :accepted
        else
          render_api_error(code: "validation_failed", message: "No active push devices", status: :unprocessable_entity)
        end
      end

      private

      def render_rate_limited
        response.set_header("Retry-After", "3600")
        render_api_error(code: "rate_limited", message: "Too many test notifications", status: :too_many_requests)
      end
    end
  end
end
