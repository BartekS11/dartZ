module Social
  class ChallengeManager
    class << self
      def create(actor:, target:, settings:)
        ApplicationRecord.transaction do
          User.where(id: [ actor.id, target.id ]).order(:id).lock.load
          Privacy.ensure_available!(actor, target)
          raise Error.forbidden("Challenges are limited to friends") unless Friendship.between(actor, target)
          raise Error.not_found unless target.challenge_policy == "friends"

          pair = pair_key(actor, target)
          existing = MatchChallenge.pending.find_by(pair_key: pair)
          if existing
            existing.expire! if existing.expired?
            return existing if existing.status == "pending" && existing.challenger_id == actor.id
            raise Error.conflict("A challenge between you is already pending") if existing.status == "pending"
          end

          match = create_invite_match(actor, settings)
          MatchChallenge.create!(challenger: actor, challenged: target, match: match)
        end
      rescue ActiveRecord::RecordNotUnique
        MatchChallenge.pending.find_by!(pair_key: pair_key(actor, target))
      end

      def accept(actor:, challenge:)
        raise Error.not_found unless challenge.challenged_id == actor.id

        expired = false
        result = ApplicationRecord.transaction do
          challenge.lock!
          if challenge.expired?
            challenge.expire!
            expired = true
            next
          end
          raise Error.conflict("Challenge is no longer pending") unless challenge.status == "pending"
          Privacy.ensure_available!(challenge.challenger, challenge.challenged)
          raise Error.forbidden("Challenges are limited to friends") unless Friendship.between(challenge.challenger, challenge.challenged)

          match = challenge.match
          match.lock!
          raise Error.conflict("Match invitation is no longer available") unless match.invite_joinable?

          player = match.players.create!(name: player_name(actor), user: actor)
          player.assign_dart_setup_snapshot!(actor.dart_setup) if actor.premium_access? && actor.dart_setup
          player.save! if player.changed?
          match.update!(invite_joined_at: Time.current)
          match.start_first_set! if match.match_sets.none?
          challenge.resolve!("accepted")
          [ challenge, player ]
        end
        raise Error.conflict("Challenge is no longer pending") if expired

        result
      end

      def decline(actor:, challenge:)
        raise Error.not_found unless challenge.challenged_id == actor.id

        resolve_and_cancel_invite(challenge, "declined")
      end

      def cancel(actor:, challenge:)
        raise Error.not_found unless challenge.challenger_id == actor.id

        resolve_and_cancel_invite(challenge, "cancelled")
      end

      private

      def create_invite_match(actor, settings)
        match = Match.new(settings.to_h)
        match.ensure_invite_token!
        match.save!
        player = match.players.create!(name: player_name(actor), user: actor)
        player.assign_dart_setup_snapshot!(actor.dart_setup) if actor.premium_access? && actor.dart_setup
        player.save! if player.changed?
        match.ensure_match_identifier!
        match
      end

      def resolve_and_cancel_invite(challenge, status)
        expired = false
        challenge.with_lock do
          if challenge.expired?
            challenge.expire!
            expired = true
          else
            challenge.resolve!(status)
            challenge.match.cancel_invite! if challenge.match.invite_pending?
          end
        end
        raise Error.conflict("Challenge is no longer pending") if expired

        challenge
      end

      def player_name(user)
        (user.nickname.presence || I18n.t("friends.player", locale: user.locale)).to_s.first(20)
      end

      def pair_key(user_a, user_b)
        [ user_a.id, user_b.id ].sort.join(":")
      end
    end
  end
end
