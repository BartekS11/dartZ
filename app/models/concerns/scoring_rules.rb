module ScoringRules
  extend ActiveSupport::Concern

  included do
    MAX_THROWS = 3
  end

  def apply_throw!(throw, broadcast: true, skip_checkout_rule: false)
      lp             = leg_player
      starting_score = lp.score
      throw_count    = throws.respond_to?(:size) ? throws.size : throws.count

      if lp.needs_double_in?
        unless throw.double?
          complete_turn!(broadcast: broadcast, voice_total: effective_turn_total) if throw_count >= max_throws
          return
        end

        lp.update!(has_doubled_in: true)
      end

      new_score = starting_score - throw.points

      if new_score < 0 || new_score == 1
        lp.update!(score: starting_score)
        complete_turn!(broadcast: broadcast)
        return
      end

      if new_score == 0
        legal_checkout = legal_checkout?(throw, skip_checkout_rule: skip_checkout_rule)
        if legal_checkout
          lp.update!(score: 0)
          leg.finish!
        else
          lp.update!(score: starting_score)
        end
        complete_turn!(broadcast: broadcast, voice_total: effective_turn_total) if legal_checkout
        complete_turn!(broadcast: broadcast) unless legal_checkout
        return
      end

      lp.update!(score: new_score)
      complete_turn!(broadcast: broadcast, voice_total: effective_turn_total) if throw_count >= max_throws
  end

  def legal_checkout?(throw, skip_checkout_rule: false)
    return true if skip_checkout_rule
    return true unless leg.match.double_out?

    throw.double?
  end

  private
    def max_throws
      self.class.const_defined?(:MAX_THROWS, false) ? self.class::MAX_THROWS : 3
    end

    def effective_turn_total
      current_throws = throws.order(:created_at, :id).to_a
      return current_throws.sum(&:points) unless leg.match.double_in?

      doubled_in_earlier = leg.turns
        .where(player_id: player_id)
        .where.not(id: id)
        .joins(:throws)
        .where(throws: { multiplier: Throw.multipliers[:double] })
        .exists?
      return current_throws.sum(&:points) if doubled_in_earlier

      first_double = current_throws.index(&:double?)
      first_double ? current_throws.drop(first_double).sum(&:points) : 0
    end
end
