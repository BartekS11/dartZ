module Training
  module Modes
    class Scoring99 < Base
      VISITS = 33

      def mode = "scoring_99"
      def defaults = {}
      def targets = (1..VISITS).map { |visit| "Visit #{visit}" }
      def rules = { visits: VISITS, darts_per_visit: 3, segments: 3 }

      def apply(session, result)
        score = result_integer!(result, "score", 0..180)
        darts = result.key?("darts") ? result_integer!(result, "darts", 1..3) : 3
        position = session.state.fetch("position", 0) + 1
        segment = ((position - 1) / 11) + 1
        segment_scores = session.state.fetch("segment_scores", {}).deep_dup
        segment_scores[segment.to_s] = segment_scores.fetch(segment.to_s, 0) + score
        state = session.state.merge("position" => position, "total_score" => session.state.fetch("total_score", 0) + score, "segment_scores" => segment_scores)
        { state: state, score: state["total_score"], darts: darts, hits: 0, successful: score.positive?, complete: position >= VISITS }
      end

      def progress(session)
        super.merge(overall_average: average(session.state.fetch("total_score", 0), session.total_darts), segment_scores: session.state.fetch("segment_scores", {}))
      end

      private

      def average(score, darts)
        darts.zero? ? nil : ((score.to_f / darts) * 3).round(2)
      end
    end
  end
end
