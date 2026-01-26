module ScoringRules
  extend ActiveSupport::Concern

  included do
    MAX_THROWS = 3
  end

  def apply_throw!(throw)
    lp = leg_player
    starting_score = lp.score
    new_score = starting_score - throw.points

    if new_score < 0 || new_score == 1
      lp.update!(score: starting_score)
      complete_turn!
      return
    end

    if new_score == 0
      if throw.double?
        lp.update!(score: 0)
        leg.finish!
      else
        lp.update!(score: starting_score)
      end

      complete_turn!
      return
    end

    lp.update!(score: new_score)

    complete_turn! if throws.count >= MAX_THROWS
  end
end
