require "digest"

module PushNotifications
  class SubscriptionRegistrar
    class << self
      def call(user:, endpoint:, p256dh:, auth:, device_label:)
        digest = Digest::SHA256.hexdigest(endpoint.to_s.strip)

        PushSubscription.transaction do
          existing = PushSubscription.lock.find_by(endpoint_digest: digest)
          existing&.destroy! if existing && existing.user_id != user.id

          subscription = PushSubscription.find_or_initialize_by(endpoint_digest: digest)
          subscription.assign_attributes(
            user: user,
            endpoint: endpoint,
            p256dh: p256dh,
            auth: auth,
            device_label: device_label.to_s.strip.presence || "Browser",
            revoked_at: nil,
            last_error_code: nil,
            failure_count: 0
          )
          subscription.save!
          subscription
        end
      rescue ActiveRecord::RecordNotUnique
        retry
      end
    end
  end
end
