module Api
  module V1
    class MatchesController < BaseController
      def index
        if current_api_user
          matches = Match.joins(:players)
                         .where(players: { user_id: current_api_user.id })
                         .includes(players: :user, match_sets: [ { legs: [ { turns: :throws }, { leg_players: :player } ] } ])
                         .distinct
                         .order(created_at: :desc)
                         .limit(20)
          render json: matches.map { |match| MatchStatePresenter.new(match).summary_payload.merge(created_at: match.created_at.iso8601, best_of_legs: match.best_of_legs, best_of_sets: match.best_of_sets) }
        else
          render json: []
        end
      end

      def show
        match = find_match
        render json: MatchStatePresenter.new(match).state_payload
      end

      def create
        match = Match.new(
          best_of_legs: params[:best_of_legs].to_i.clamp(1, 99),
          best_of_sets: params[:best_of_sets].to_i.clamp(1, 99)
        )

        p1_name = params[:player1_name].to_s.strip.presence || current_api_user&.display_name || "Player 1"
        p2_name = params[:player2_name].to_s.strip.presence || "Player 2"

        match.save!

        current_api_user&.update!(nickname: p1_name) if current_api_user && current_api_user.nickname != p1_name

        player1 = match.players.create!(name: p1_name, user: current_api_user)
        player2 = match.players.create!(name: p2_name)

        match.ensure_match_identifier!
        match.start_first_set!

        render json: MatchStatePresenter.new(match).state_payload, status: :created
      end

      private

      def find_match
        Match.includes(players: :user, match_sets: [ { legs: [ { turns: :throws }, { leg_players: :player } ] } ]).find(params[:id])
      end
    end
  end
end
