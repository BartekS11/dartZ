module Api
  module V1
    class SocialSerializer
      def initialize(viewer:, users:)
        @viewer = viewer
        user_ids = users.map(&:id).uniq - [ viewer.id ]
        @friend_ids = load_friend_ids(user_ids)
        @requests_by_pair = load_requests(user_ids)
      end

      def user(user)
        request = @requests_by_pair[pair_key(user)]
        state = if @friend_ids.include?(user.id)
          "friends"
        elsif request&.requester_id == @viewer.id
          "request_sent"
        elsif request
          "request_received"
        else
          "none"
        end

        {
          id: user.public_id,
          nickname: user.nickname.presence || I18n.t("friends.player"),
          friendship_state: state,
          can_challenge: @friend_ids.include?(user.id) && user.challenge_policy == "friends"
        }
      end

      def friendship(friendship)
        {
          id: friendship.public_id,
          user: user(friendship.other_user(@viewer)),
          created_at: friendship.created_at.iso8601
        }
      end

      def request(request)
        other = request.other_user(@viewer)
        {
          id: request.public_id,
          direction: request.requester_id == @viewer.id ? "outgoing" : "incoming",
          status: request.status,
          user: user(other),
          created_at: request.created_at.iso8601
        }
      end

      def block(block)
        { id: block.public_id, user: user(block.blocked), created_at: block.created_at.iso8601 }
      end

      def challenge(challenge)
        other = challenge.other_user(@viewer)
        {
          id: challenge.public_id,
          direction: challenge.challenger_id == @viewer.id ? "outgoing" : "incoming",
          status: challenge.expired? ? "expired" : challenge.status,
          user: user(other),
          settings: challenge.match.game_settings.merge(
            best_of_legs: challenge.match.best_of_legs,
            best_of_sets: challenge.match.best_of_sets
          ),
          expires_at: challenge.expires_at.iso8601,
          created_at: challenge.created_at.iso8601
        }
      end

      private

      def load_friend_ids(user_ids)
        return {} if user_ids.empty?

        Friendship.for_user(@viewer)
          .where("user_low_id IN (:ids) OR user_high_id IN (:ids)", ids: user_ids)
          .pluck(:user_low_id, :user_high_id)
          .flatten
          .index_with(true)
          .tap { |ids| ids.delete(@viewer.id) }
      end

      def load_requests(user_ids)
        return {} if user_ids.empty?

        FriendRequest.for_user(@viewer).pending
          .where("requester_id IN (:ids) OR recipient_id IN (:ids)", ids: user_ids)
          .index_by do |request|
            other_id = request.requester_id == @viewer.id ? request.recipient_id : request.requester_id
            pair_key_for_id(other_id)
          end
      end

      def pair_key(user)
        pair_key_for_id(user.id)
      end

      def pair_key_for_id(user_id)
        [ @viewer.id, user_id ].sort.join(":")
      end
    end
  end
end
