module ScoringRules
  extend ActiveSupport::Concern

  included do
    MAX_THROWS = 3
  end

  def apply_throw!(throw, broadcast: true, skip_checkout_rule: false)
      lp             = leg_player
      starting_score = lp.score
      new_score      = starting_score - throw.points

      if new_score < 0 || new_score == 1
        lp.update!(score: starting_score)
        complete_turn!(broadcast: broadcast)
        return
      end

      if new_score == 0
        if skip_checkout_rule || throw.double?
          lp.update!(score: 0)
          leg.finish!
        else
          lp.update!(score: starting_score)
        end
        complete_turn!(broadcast: broadcast)
        return
      end

      lp.update!(score: new_score)
      complete_turn!(broadcast: broadcast) if throws.count >= max_throws
  end

  private
    def max_throws
    self.class.const_defined?(:MAX_THROWS, false) ? self.class::MAX_THROWS : 3
  end
end
