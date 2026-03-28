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
        render json: match_state(@match), status: :created
      end

      def undo
        @turn  = Turn.find(params[:turn_id])
        @match = @turn.leg.match
        mode   = params[:mode] || "single"

        @match.undo_last_throw!(mode: mode)
        @match.reload

        render json: match_state(@match)
      end

      private

      def find_current_turn
        match = Match.find(params[:match_id])
        match.current_leg&.current_turn&.id or
          raise ActiveRecord::RecordNotFound, "No active turn"
      end

      def match_state(match)
        current_leg  = match.current_leg
        current_turn = current_leg&.current_turn

        {
          id:              match.id,
          finished:        match.finished?,
          current_player:  match.current_player&.display_name,
          current_turn_id: current_turn&.id,
          players:         match.players.map { |p|
            {
              id:          p.id,
              name:        p.display_name,
              score:       match.score_for(p),
              avg:         match.three_dart_average(p),
              sets_won:    match.sets_won_by(p),
              legs_won:    current_leg ? match.current_set&.legs_won_by(p) : 0,
              winner:      match.winner == p,
              last_throws: match.last_turn_throws_for(p).map { |t|
                {
                  segment:    t.segment,
                  multiplier: t.multiplier,
                  points:     t.points
                }
              },
              checkout: CheckoutCalculator.suggest(match.score_for(p))
            }
          }
        }
      end
    end
  end
end
