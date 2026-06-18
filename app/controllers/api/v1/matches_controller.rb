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
        match = Match.new(
          best_of_legs: params[:best_of_legs].to_i.clamp(1, 99),
          best_of_sets: params[:best_of_sets].to_i.clamp(1, 99),
          starting_score: permitted_starting_score,
          double_in: truthy_param?(:double_in),
          double_out: truthy_param?(:double_out, default: true),
          guest_id: current_api_user ? nil : current_guest_id
        )
        p1_name = params[:player1_name].to_s.strip.presence || current_api_user&.display_name || "Player 1"
        p2_name = params[:player2_name].to_s.strip.presence || "Player 2"

        ApplicationRecord.transaction do
          match.ensure_guest_token! unless current_api_user
          match.save!

          current_api_user&.update!(nickname: p1_name) if current_api_user && current_api_user.nickname != p1_name

          match.players.create!(name: p1_name, user: current_api_user)
          match.players.create!(name: p2_name)

          match.ensure_match_identifier!
          match.start_first_set!
        end

        render json: MatchStatePresenter.new(match).state_payload, status: :created
      end

      private

      def permitted_starting_score
        score = params[:starting_score].to_i
        Match::X01_STARTING_SCORES.include?(score) ? score : 501
      end

      def truthy_param?(key, default: false)
        return default unless params.key?(key)

        ActiveModel::Type::Boolean.new.cast(params[key])
      end

      def find_match
        match = Match.includes(players: :user, match_sets: [ { legs: [ { turns: :throws }, { leg_players: :player } ] } ]).find(params[:id])
        authorize_api_match!(match)
        match
      end
    end
  end
end
