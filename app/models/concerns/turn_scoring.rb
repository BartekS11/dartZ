module TurnScoring
  extend ActiveSupport::Concern

  included do
    # nothing needed here
  end

  def distribute_total!(total, skip_checkout_rule: true)
     active_turn = leg.match.current_leg.current_turn
     return unless active_turn && !active_turn.completed?

     if total == 0
       throw_record = active_turn.throws.create!(segment: 0, multiplier: :miss)
       active_turn.apply_throw!(throw_record, broadcast: false, skip_checkout_rule: skip_checkout_rule)
       return
     end

     chunks = split_into_valid_chunks(total)

     chunks.each do |points|
       active_turn = leg.match.current_leg.current_turn
       break unless active_turn
       break if active_turn.completed?

       segment, multiplier = self.class.points_to_segment(points)
       throw_record        = active_turn.throws.create!(segment: segment, multiplier: multiplier)
       active_turn.apply_throw!(throw_record, broadcast: false, skip_checkout_rule: skip_checkout_rule)
     end
  end

  module ClassMethods
    def points_to_segment(points)
      (1..20).each { |s| return [ s, "triple" ] if s * 3 == points }
      (1..20).each { |s| return [ s, "double" ] if s * 2 == points }
      return [ points, "single" ] if points >= 1 && points <= 20
      return [ 25, "double" ] if points == 50
      return [ 25, "single" ] if points == 25
      [ 1, "single" ]
    end
  end

  private

  def split_into_valid_chunks(total)
    valid = ((1..20).to_a +
             (1..20).map { |s| s * 2 } +
             (1..20).map { |s| s * 3 } +
             [ 25, 50 ]).uniq.sort.reverse

    remaining = total
    chunks    = []

    3.times do
      break if remaining == 0
      chunk = valid.find { |v| v <= remaining }
      break unless chunk
      chunks << chunk
      remaining -= chunk
    end

    chunks.empty? ? [ total ] : chunks
  end
end
