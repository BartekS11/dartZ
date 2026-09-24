class PushSubscriptionsController < ApplicationController
  before_action -> { require_roadmap_feature!(:web_push) }

  rate_limit to: 10, within: 1.hour, only: :test, by: -> { Current.user.id },
    with: -> { render json: { error: t("push.flashes.rate_limited") }, status: :too_many_requests }

  def create
    subscription = PushNotifications::SubscriptionRegistrar.call(user: Current.user, **subscription_params.to_h.symbolize_keys)
    render json: { data: serialize(subscription) }, status: :created
  rescue ActionController::ParameterMissing, ActiveRecord::RecordInvalid => error
    render json: { error: t("push.flashes.invalid_subscription"), details: validation_details(error) }, status: :unprocessable_entity
  end

  def destroy
    Current.user.push_subscriptions.find_by!(public_id: params[:id]).revoke!(error_code: "user_removed")
    respond_to do |format|
      format.html { redirect_to notifications_path, notice: t("push.flashes.device_removed") }
      format.json { head :no_content }
    end
  end

  def test
    deliveries = PushNotifications::Notifier.test(Current.user)
    if deliveries.any?
      render json: { queued: true }, status: :accepted
    else
      render json: { error: t("push.flashes.no_devices") }, status: :unprocessable_entity
    end
  end

  private

  def subscription_params
    keys = params.require(:subscription).require(:keys).permit(:p256dh, :auth)
    params.require(:subscription).permit(:endpoint, :device_label).merge(keys: keys).then do |permitted|
      {
        endpoint: permitted[:endpoint],
        device_label: permitted[:device_label],
        p256dh: keys[:p256dh],
        auth: keys[:auth]
      }
    end
  end

  def serialize(subscription)
    {
      id: subscription.public_id,
      device_label: subscription.device_label,
      created_at: subscription.created_at.iso8601,
      last_success_at: subscription.last_success_at&.iso8601
    }
  end

  def validation_details(error)
    error.respond_to?(:record) ? error.record.errors.to_hash : {}
  end
end
