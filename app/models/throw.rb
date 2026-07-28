class Throw < ApplicationRecord
  belongs_to :turn
  after_create_commit :broadcast_match_update
  validate :max_three_throws

  validates :segment,
            numericality: {
              only_integer: true,
              greater_than_or_equal_to: 0,
              less_than_or_equal_to: 25
            }

  validates :segment,
            inclusion: {
              in: [ 0 ] + (1..20).to_a + [ 25 ],
              message: "must be 0 (miss), 1-20, or 25 (bull)"
            }

  enum :multiplier, {
    miss:   0,
    single: 1,
    double: 2,
    triple: 3
  }

  validates :multiplier,
            inclusion: {
              in: %w[single double],
              message: "bull can only be single or double"
            },
            if: -> { segment == 25 }

  def points
    Darts::Core::Throw.new(segment: segment, multiplier: multiplier).points
  end

  private

  def max_three_throws
    return unless turn
    return if persisted?

    if turn.throws.size >= Turn::MAX_THROWS
      errors.add(:base, "Maximum of 3 throws per turn")
    end
  end

  def broadcast_match_update
    match = turn.leg.match_set.match

    match.broadcast_replace_to(
      "match_#{match.id}",
      target: "match-live",
      partial: "matches/live",
      locals: { match: match }
    )
  end
end
