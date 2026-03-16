module TurnScoring
  extend ActiveSupport::Concern

  def distribute_total!(total, skip_checkout_rule: true)
    remaining   = total
    throws_made = 0

    while remaining > 0 && throws_made < 3
      active_turn = leg.match.current_leg.current_turn
      break unless active_turn
      break if active_turn.completed?

      points              = [ remaining, 60 ].min
      segment, multiplier = self.class.points_to_segment(points)
      throw_record        = active_turn.throws.create!(
                              segment:    segment,
                              multiplier: multiplier
                            )
      active_turn.apply_throw!(throw_record,
                                broadcast:           false,
                                skip_checkout_rule:  skip_checkout_rule)

      remaining   -= points
      throws_made += 1
    end

    # Force complete if still open after all throws
    reload
    if !completed?
      complete_turn!(broadcast: false)
    end
  end

  module ClassMethods
    def points_to_segment(points)
      (1..20).each { |s| return [ s, "triple" ] if s * 3 == points }
      (1..20).each { |s| return [ s, "double" ] if s * 2 == points }
      (1..20).each { |s| return [ s, "single" ] if s       == points }
      return [ 25, "double" ] if points == 50
      return [ 25, "single" ] if points == 25
      [ 1, "single" ]
    end
  end
end
