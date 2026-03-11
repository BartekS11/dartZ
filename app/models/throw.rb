class Throw < ApplicationRecord
  belongs_to :turn

  validate :max_three_throws

  validates :segment,
            numericality: {
              only_integer: true,
              greater_than: 0,
              less_than_or_equal_to: 25  # 25 = bull
            }

  validates :segment,
            inclusion: {
              in: (1..20).to_a + [ 25 ],
              message: "must be 1-20 or 25 (bull)"
            }

  enum :multiplier, {
    single: 1,
    double: 2,
    triple: 3
  }

  # Bull can only be single or double
  validates :multiplier,
            inclusion: {
              in: %w[single double],
              message: "bull can only be single or double"
            },
            if: -> { segment == 25 }

  def points
    segment * self.class.multipliers.fetch(multiplier)
  end

  private

  def max_three_throws
    return unless turn
    return if persisted?

    if turn.throws.count >= Turn::MAX_THROWS
      errors.add(:base, "Maximum of 3 throws per turn")
    end
  end
end
