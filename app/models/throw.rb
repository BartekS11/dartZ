class Throw < ApplicationRecord
  belongs_to :turn

  enum :multiplier, { single: 1, double: 2, triple: 3 }
validate :max_three_throws_per_turn
  validates :segment, inclusion: { in: 1..20 }

  def points
    segment.to_i * self.class.multipliers[multiplier]
  end

  private

  def max_three_throws_per_turn
    return unless turn

    if turn.throws.count >= 3
      errors.add(:base, "Maximum of 3 throws per turn")
    end
  end
end
