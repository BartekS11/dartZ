module Api
  module V1
    class ThrowsController < BaseController
      def create
        @turn  = params[:match_id] ? find_current_turn : Turn.find_by_public_id!(params[:turn_id])
        @match = @turn.leg.match
        authorize_api_match!(@match)

        @match = ThrowSubmission.call(
          turn: @turn,
          total: params[:total],
          throw_attributes: {
            segment: params[:segment].to_i,
            multiplier: params[:multiplier].to_s
          }
        )
        broadcast_tournament_update!
        render json: MatchStatePresenter.new(@match).state_payload, status: :created
      end

      def undo
        @turn  = params[:match_id] ? find_current_turn : Turn.find_by_public_id!(params[:turn_id])
        @match = @turn.leg.match
        authorize_api_match!(@match)

        mode   = params[:mode] || "single"

        @match.with_lock do
          @match.undo_last_throw!(mode: mode)
          @match.reload
        end

        broadcast_tournament_update!
        render json: MatchStatePresenter.new(@match).state_payload
      end

      private

      def broadcast_tournament_update!
        tournament_match = TournamentMatch.find_by(linked_match: @match)
        return unless tournament_match

        tournament = tournament_match.tournament
        tournament.sync_from_linked_matches! if @match.finished?
        tournament.broadcast_live_update!
      end

      def find_current_turn
        match = Match.find_by_public_id!(params[:match_id])
        authorize_api_match!(match)
        match.current_leg&.current_turn or
          raise ActiveRecord::RecordNotFound, "No active turn"
      end
    end
  end
end
