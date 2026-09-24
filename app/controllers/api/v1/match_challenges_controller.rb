module Api
  module V1
    class MatchChallengesController < SocialController
      rate_limit to: 20, within: 1.hour, only: :create, by: -> { current_api_user&.id || request.remote_ip },
        with: -> { render_rate_limited }

      def index
        scope = MatchChallenge.for_user(current_api_user).includes(:challenger, :challenged, :match)
          .order(created_at: :desc, public_id: :desc)
        records, pagination = paginate(scope)
        serializer = serializer_for(records.map { |record| record.other_user(current_api_user) })
        render json: { data: records.map { |record| serializer.challenge(record) }, pagination: pagination }
      end

      def create
        challenge = Social::ChallengeManager.create(
          actor: current_api_user,
          target: find_target,
          settings: MatchSettings.from_params(params)
        )
        serializer = serializer_for([ challenge.other_user(current_api_user) ])
        render json: { data: serializer.challenge(challenge) }, status: :created
      end

      def accept
        challenge, player = Social::ChallengeManager.accept(actor: current_api_user, challenge: find_challenge)
        serializer = serializer_for([ challenge.other_user(current_api_user) ])
        render json: {
          data: serializer.challenge(challenge).merge(
            match_id: challenge.match.public_id,
            player_id: player.public_id,
            match_url: Rails.application.routes.url_helpers.match_path(challenge.match, player_id: player.public_id)
          )
        }
      end

      def decline
        challenge = find_challenge
        Social::ChallengeManager.decline(actor: current_api_user, challenge: challenge)
        serializer = serializer_for([ challenge.other_user(current_api_user) ])
        render json: { data: serializer.challenge(challenge) }
      end

      def destroy
        Social::ChallengeManager.cancel(actor: current_api_user, challenge: find_challenge)
        head :no_content
      end

      private

      def find_challenge
        MatchChallenge.find_by_public_id!(params[:id])
      end

      def render_rate_limited
        response.set_header("Retry-After", "3600")
        render_api_error(code: "rate_limited", message: "Too many challenges", status: :too_many_requests)
      end
    end
  end
end
