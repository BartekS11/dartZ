module Social
  class FriendshipManager
    class << self
      def send_request(actor:, target:, share_code: nil)
        with_users_locked(actor, target) do
          Privacy.ensure_available!(actor, target)
          raise Error.conflict("You are already friends") if Friendship.between(actor, target)
          ensure_request_allowed!(target, share_code)

          pair_key = pair_key(actor, target)
          existing = FriendRequest.pending.find_by(pair_key: pair_key)
          if existing
            return existing if existing.requester_id == actor.id
            raise Error.conflict("A request from this user is already waiting for you")
          end

          FriendRequest.create!(requester: actor, recipient: target)
        end
      rescue ActiveRecord::RecordNotUnique
        FriendRequest.pending.find_by!(pair_key: pair_key(actor, target))
      end

      def accept(actor:, request:)
        raise Error.not_found unless request.recipient_id == actor.id

        with_users_locked(request.requester, request.recipient) do
          request.lock!
          raise Error.conflict("Request is no longer pending") unless request.pending?
          Privacy.ensure_available!(request.requester, request.recipient)
          friendship = Friendship.between(request.requester, request.recipient) ||
            Friendship.create_between!(request.requester, request.recipient)
          request.resolve!("accepted")
          friendship
        end
      rescue ActiveRecord::RecordNotUnique
        request.resolve!("accepted") if request.reload.pending?
        Friendship.between(request.requester, request.recipient)
      end

      def decline(actor:, request:)
        raise Error.not_found unless request.recipient_id == actor.id

        request.with_lock { request.resolve!("declined") }
      end

      def cancel(actor:, request:)
        raise Error.not_found unless request.requester_id == actor.id

        request.with_lock { request.resolve!("cancelled") }
      end

      def remove(actor:, friendship:)
        raise Error.not_found unless [ friendship.user_low_id, friendship.user_high_id ].include?(actor.id)

        friendship.destroy!
      end

      def block(actor:, target:)
        raise Error.not_found if actor == target

        with_users_locked(actor, target) do
          block = UserBlock.find_or_create_by!(blocker: actor, blocked: target)
          Friendship.between(actor, target)&.destroy!
          FriendRequest.pending.where(pair_key: pair_key(actor, target)).update_all(status: "cancelled", resolved_at: Time.current)
          MatchChallenge.pending.where(pair_key: pair_key(actor, target)).find_each do |challenge|
            challenge.update!(status: "cancelled", resolved_at: Time.current)
            challenge.match.cancel_invite! if challenge.match.invite_pending?
          end
          block
        end
      end

      def unblock(actor:, block:)
        raise Error.not_found unless block.blocker_id == actor.id

        block.destroy!
      end

      private

      def ensure_request_allowed!(target, share_code)
        allowed = case target.friend_request_policy
        when "anyone" then true
        when "share_code_only" then ActiveSupport::SecurityUtils.secure_compare(
          target.friend_share_code,
          share_code.to_s.delete("- ").upcase
        )
        else false
        end
        raise Error.not_found unless allowed
      end

      def pair_key(user_a, user_b)
        [ user_a.id, user_b.id ].sort.join(":")
      end

      def with_users_locked(user_a, user_b, &block)
        ApplicationRecord.transaction do
          User.where(id: [ user_a.id, user_b.id ]).order(:id).lock.load
          yield
        end
      end
    end
  end
end
