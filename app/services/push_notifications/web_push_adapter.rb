require "socket"
require "timeout"

module PushNotifications
  class WebPushAdapter
    PERMANENT_STATUS_CODES = [ 404, 410 ].freeze

    def deliver(subscription:, payload:)
      Webpush.payload_send(
        message: JSON.generate(payload),
        endpoint: subscription.endpoint,
        p256dh: subscription.p256dh,
        auth: subscription.auth,
        vapid: {
          subject: configuration.subject,
          public_key: configuration.public_key,
          private_key: configuration.private_key
        }
      )
    rescue Webpush::InvalidSubscription, Webpush::ExpiredSubscription => error
      raise PermanentDeliveryError.new(error.message, code: error.class.name.demodulize.underscore)
    rescue Webpush::ResponseError => error
      status = error.response&.code.to_i
      error_class = PERMANENT_STATUS_CODES.include?(status) ? PermanentDeliveryError : TransientDeliveryError
      raise error_class.new(error.message, code: "http_#{status.nonzero? || 'error'}")
    rescue Timeout::Error, SocketError, Errno::ECONNRESET, Errno::ECONNREFUSED => error
      raise TransientDeliveryError.new(error.message, code: error.class.name.demodulize.underscore)
    end

    private

    def configuration
      Rails.application.config.x.web_push
    end
  end
end
