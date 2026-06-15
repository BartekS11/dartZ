module TurnScoring
  extend ActiveSupport::Concern

  included do
  end

  def distribute_total!(total, skip_checkout_rule: true)
    active_turn = leg.match.current_leg&.current_turn
    return unless active_turn && !active_turn.completed?

    if total == 0
      throw_record = active_turn.throws.create!(segment: 0, multiplier: :miss)
      active_turn.apply_throw!(throw_record, broadcast: false, skip_checkout_rule: skip_checkout_rule)
      active_turn.reload
      active_turn.complete_turn!(broadcast: false) unless active_turn.completed?
      return
    end

    chunks = split_into_valid_chunks(total)

    unless chunks
      active_turn.complete_turn!(broadcast: false) unless active_turn.completed?
      return
    end

    chunks.each do |points|
      current_leg = leg.match.current_leg
      break unless current_leg
      active_turn = current_leg.current_turn
      break unless active_turn
      break if active_turn.completed?

      segment, multiplier = self.class.points_to_segment(points)
      throw_record        = active_turn.throws.create!(segment: segment, multiplier: multiplier)
      active_turn.apply_throw!(throw_record, broadcast: false, skip_checkout_rule: skip_checkout_rule)
    end

    # Force complete — player declared their full turn total
    current_leg = leg.match.current_leg
    if current_leg
      active_turn = current_leg.current_turn
      if active_turn && active_turn == self && !active_turn.completed?
        active_turn.complete_turn!(broadcast: false)
      end
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

    find_exact_chunks(total, 3, valid)
  end

  def find_exact_chunks(remaining, darts_left, valid)
    return [] if remaining.zero?
    return nil if darts_left.zero? || remaining.negative?

    valid.each do |points|
      next if points > remaining

      tail = find_exact_chunks(remaining - points, darts_left - 1, valid)
      return [ points, *tail ] if tail
    end

    nil
  end
end
