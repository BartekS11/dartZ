module Api
  module V1
    class MatchesController < BaseController
      def index
        if current_api_user
          matches = Match.joins(:players)
                         .where(players: { user_id: current_api_user.id })
                         .distinct
                         .order(created_at: :desc)
                         .limit(20)
          render json: matches.map { |m| match_summary(m) }
        else
          render json: []
        end
      end

      def show
        match = find_match
        render json: match_state(match)
      end

      def create
        match = Match.new(
          best_of_legs: params[:best_of_legs].to_i.clamp(1, 99),
          best_of_sets: params[:best_of_sets].to_i.clamp(1, 99)
        )

        p1_name = params[:player1_name].to_s.strip.presence || "Player 1"
        p2_name = params[:player2_name].to_s.strip.presence || "Player 2"

        match.save!

        player1 = match.players.create!(name: p1_name, user: current_api_user)
        player2 = match.players.create!(name: p2_name)

        match.ensure_match_identifier!
        match.start_first_set!

        render json: match_state(match), status: :created
      end

      private

      def find_match
        Match.find(params[:id])
      end

      def match_summary(match)
        {
          id:               match.id,
          match_identifier: match.match_identifier,
          finished:         match.finished?,
          created_at:   match.created_at.iso8601,
          best_of_legs: match.best_of_legs,
          best_of_sets: match.best_of_sets,
          players:      match.players.map { |p|
            {
              id:     p.id,
              name:   p.display_name,
              score:  match.score_for(p),
              avg:    match.three_dart_average(p),
              winner: match.winner == p
            }
          }
        }
      end

      def match_state(match)
        current_leg  = match.current_leg
        current_turn = current_leg&.current_turn

        {
          id:               match.id,
          match_identifier: match.match_identifier,
          finished:         match.finished?,
          best_of_legs:   match.best_of_legs,
          best_of_sets:   match.best_of_sets,
          winner:         match.winner&.display_name,
          current_player: match.current_player&.display_name,
          current_turn_id: current_turn&.id,
          players:        match.players.map { |p|
            {
              id:           p.id,
              name:         p.display_name,
              score:        match.score_for(p),
              avg:          match.three_dart_average(p),
              sets_won:     match.sets_won_by(p),
              legs_won:     current_leg ? match.current_set&.legs_won_by(p) : 0,
              winner:       match.winner == p,
              last_throws:  match.last_turn_throws_for(p).map { |t|
                {
                  segment:    t.segment,
                  multiplier: t.multiplier,
                  points:     t.points
                }
              },
              checkout:     CheckoutCalculator.suggest(match.score_for(p))
            }
          }
        }
      end
    end
  end
end
