class PushDeliveryJob < ApplicationJob
  queue_as :default
  self.enqueue_after_transaction_commit = true

  MAX_ATTEMPTS = 4
  RETRY_DELAYS = [ 30.seconds, 2.minutes, 10.minutes ].freeze

  def perform(delivery_id)
    delivery = PushDelivery.find(delivery_id)
    return unless delivery.status == "pending"

    subscription = delivery.push_subscription
    return cancel(delivery) unless subscription.revoked_at.nil?

    delivery.increment!(:attempts)
    delivery_adapter.deliver(subscription: subscription, payload: browser_payload(delivery))
    delivery.update!(status: "delivered", delivered_at: Time.current, last_error_code: nil)
    subscription.record_success!
  rescue PushNotifications::PermanentDeliveryError => error
    delivery&.update!(status: "failed", last_error_code: error.code)
    subscription&.revoke!(error_code: error.code)
  rescue PushNotifications::TransientDeliveryError => error
    handle_transient_failure(delivery, subscription, error)
  end

  private

  def browser_payload(delivery)
    data = delivery.payload.to_h
    {
      title: data.fetch("title"),
      options: {
        body: data.fetch("body"),
        tag: delivery.deduplication_key,
        renotify: false,
        data: { path: data.fetch("path") }
      }
    }
  end

  def delivery_adapter
    Rails.application.config.x.web_push.delivery_adapter || PushNotifications::WebPushAdapter.new
  end

  def handle_transient_failure(delivery, subscription, error)
    return unless delivery && subscription

    subscription.record_failure!(error.code)
    if delivery.attempts >= MAX_ATTEMPTS
      delivery.update!(status: "failed", last_error_code: error.code)
    else
      delivery.update!(last_error_code: error.code)
      retry_job wait: RETRY_DELAYS.fetch(delivery.attempts - 1)
    end
  end

  def cancel(delivery)
    delivery.update!(status: "cancelled")
  end
end
