module Training
  module Modes
    class Bobs27 < Base
      def mode = "bobs_27"
      def defaults = { "starting_score" => 27 }
      def initial_score = configuration.fetch("starting_score")
      def targets = (1..20).map { |number| "D#{number}" } + [ "Bull" ]
      def rules = { darts_per_target: 3, miss_penalty: "double_value", early_termination_below: 0 }

      def validate!
        integer!("starting_score", 1..999)
      end

      def apply(session, result)
        hits = result_integer!(result, "hits", 0..3)
        position = session.state.fetch("position", 0)
        raise Training::InvalidAttempt, "session has no remaining target" if position >= targets.length

        value = position == 20 ? 50 : (position + 1) * 2
        score = session.score || initial_score
        score += hits.positive? ? hits * value : -value
        state = session.state.merge("position" => position + 1, "ended_below_zero" => score.negative?)
        { state: state, score: score, darts: 3, hits: hits, successful: hits.positive?, complete: score.negative? || state["position"] >= targets.length }
      end
    end
  end
end
