class Throw < ApplicationRecord
  belongs_to :turn

  validate :max_three_throws
  validate :does_not_bust_leg

  validates :segment,
            numericality: { only_integer: true, greater_than: 0, less_than_or_equal_to: 20 }

  enum :multiplier, {
    single: 1,
    double: 2,
    triple: 3
  }

  def points
    segment* self.class.multipliers.fetch(multiplier)
  end

  private


def max_three_throws
  return unless turn
  return if persisted?

  if turn.throws.count >= Turn::MAX_THROWS
    errors.add(:base, "Maximum of 3 throws per turn")
  end
end


  def does_not_bust_leg
    leg_player = turn.leg.leg_players.find_by!(player: turn.player)

    new_score = leg_player.score - points

    if new_score < 0 || new_score == 1
      errors.add(:base, "Bust")
    end
  end
end
