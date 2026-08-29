module Api
  module V1
    class MatchesController < BaseController
      def index
        matches = if current_api_user
          Match.joins(:players)
               .where(players: { user_id: current_api_user.id })
        elsif current_guest_id
          Match.where(guest_id: current_guest_id)
        else
          Match.none
        end

        matches = matches.includes(players: :user, match_sets: [ { legs: [ { turns: :throws }, { leg_players: :player } ] } ])
                         .distinct
                         .order(created_at: :desc)
                         .limit(20)
        render json: matches.map { |match| MatchStatePresenter.new(match).summary_payload.merge(created_at: match.created_at.iso8601, best_of_legs: match.best_of_legs, best_of_sets: match.best_of_sets) }
      end

      def show
        match = find_match
        render json: MatchStatePresenter.new(match).state_payload
      end

      def create
        p1_name = params[:player1_name].to_s.strip.presence || current_api_user&.display_name || "Player 1"
        p2_name = params[:player2_name].to_s.strip.presence || "Player 2"

        match = MatchCreator.call(
          settings: MatchSettings.from_params(params),
          players: [
            { name: p1_name, user: current_api_user },
            { name: p2_name }
          ],
          guest_match: current_api_user.nil?,
          guest_id: current_api_user ? nil : current_guest_id,
          nickname_user: current_api_user,
          nickname: p1_name
        )

        render json: MatchStatePresenter.new(match).state_payload, status: :created
      end

      private

      def find_match
        match = Match.includes(players: :user, match_sets: [ { legs: [ { turns: :throws }, { leg_players: :player } ] } ]).find_by_public_id!(params[:id])
        authorize_api_match!(match)
        match
      end
    end
  end
end
