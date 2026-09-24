module PushNotifications
  class Notifier
    class << self
      def friend_request(request)
        dispatch(
          user: request.recipient,
          category: :friend_requests,
          deduplication_key: "friend-request:#{request.public_id}",
          message_key: :friend_request,
          actor: request.requester,
          path: Rails.application.routes.url_helpers.friends_path
        )
      end

      def friendship_accepted(request)
        dispatch(
          user: request.requester,
          category: :friendship_acceptance,
          deduplication_key: "friendship-accepted:#{request.public_id}",
          message_key: :friendship_accepted,
          actor: request.recipient,
          path: Rails.application.routes.url_helpers.friends_path
        )
      end

      def match_challenge(challenge)
        dispatch(
          user: challenge.challenged,
          category: :match_challenges,
          deduplication_key: "match-challenge:#{challenge.public_id}",
          message_key: :match_challenge,
          actor: challenge.challenger,
          path: Rails.application.routes.url_helpers.friends_path
        )
      end

      def tournament_round_ready(tournament_match, user)
        dispatch(
          user: user,
          category: :tournament_round_ready,
          deduplication_key: "tournament-match-ready:#{tournament_match.public_id}:#{user.public_id}",
          message_key: :tournament_round_ready,
          tournament_name: tournament_match.tournament.title,
          path: Rails.application.routes.url_helpers.tournament_path(tournament_match.tournament)
        )
      end

      def test(user)
        dispatch(
          user: user,
          category: :test,
          deduplication_key: "test:#{SecureRandom.uuid}",
          message_key: :test,
          path: Rails.application.routes.url_helpers.notifications_path,
          ignore_preference: true
        )
      end

      private

      def dispatch(user:, category:, deduplication_key:, message_key:, path:, ignore_preference: false, **interpolations)
        return [] unless FeatureAccess.available?(:web_push, user: user)
        return [] unless configured?

        preference = user.notification_preference || NotificationPreference.create_or_find_by!(user: user)
        return [] if !ignore_preference && !preference.enabled?(category)

        locale = User::LOCALES.include?(user.locale) ? user.locale : I18n.default_locale
        actor = interpolations.delete(:actor)
        payload = I18n.with_locale(locale) do
          interpolations[:actor_name] = actor.nickname.presence || I18n.t("friends.player") if actor
          {
            title: I18n.t("push.messages.#{message_key}.title", **interpolations),
            body: I18n.t("push.messages.#{message_key}.body", **interpolations),
            path: path
          }
        end

        user.push_subscriptions.active.filter_map do |subscription|
          delivery = subscription.push_deliveries.find_or_create_by!(deduplication_key: deduplication_key) do |record|
            record.category = category
            record.payload = payload
          end
          next unless delivery.previously_new_record?

          PushDeliveryJob.perform_later(delivery.id)
          delivery
        rescue ActiveRecord::RecordNotUnique
          nil
        end
      end

      def configured?
        configuration = Rails.application.config.x.web_push
        configuration.public_key.present? && configuration.private_key.present? && configuration.subject.present?
      end
    end
  end
end
