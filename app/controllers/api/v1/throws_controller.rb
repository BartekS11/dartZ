module Api
  module V1
    class ThrowsController < BaseController
      def create
        @turn  = Turn.find(params[:match_id] ? find_current_turn : params[:turn_id])
        @match = @turn.leg.match

        if params[:total].present?
          total           = params[:total].to_i
          darts_remaining = 3 - @turn.throws.count
          max_possible    = darts_remaining * 60

          @turn.update!(total_score: total)

          if total > max_possible || total > @match.score_for(@turn.player)
            @turn.complete_turn!(broadcast: false)
          else
            @turn.distribute_total!(total)
          end
        else
          segment    = params[:segment].to_i
          multiplier = params[:multiplier].to_s

          @throw = @turn.throws.create!(segment: segment, multiplier: multiplier)
          @turn.apply_throw!(@throw)
        end

        @match.reload
        render json: MatchStatePresenter.new(@match).state_payload, status: :created
      end

      def undo
        @turn  = Turn.find(params[:turn_id])
        @match = @turn.leg.match
        mode   = params[:mode] || "single"

        @match.undo_last_throw!(mode: mode)
        @match.reload

        render json: MatchStatePresenter.new(@match).state_payload
      end

      private

      def find_current_turn
        match = Match.find(params[:match_id])
        match.current_leg&.current_turn&.id or
          raise ActiveRecord::RecordNotFound, "No active turn"
      end
    end
  end
end
