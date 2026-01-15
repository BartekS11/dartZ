class Turn < ApplicationRecord
  belongs_to :leg
  belongs_to :player
  has_many :throws, dependent: :destroy

  MAX_THROWS = 3

  validate :max_three_throws, on: :update

  def remaining_score
    starting_score - throws.sum(&:points)
  end

  def busted?
    remaining_score < 0 || remaining_score == 1
  end

  def finished?
    remaining_score == 0 && throws.last&.double?
  end

  def complete?
    throws.size >= MAX_THROWS || busted? || finished?
  end

def complete!
  return unless complete?

  transaction do
    if finished?
      leg.update!(finished_at: Time.current)
    elsif busted?
      throws.destroy_all
    else
      leg.update!(starting_score: remaining_score)
    end

    start_next_turn! unless finished?
  end
end

  private

  def start_next_turn!
    players = leg.match.players.order(:id).to_a
    current_index = players.index(player)
    next_player = players[(current_index + 1) % players.size]

    leg.turns.create!(
      player: next_player,
      starting_score: leg.starting_score
    )
  end

  def max_three_throws
    if throws.size > MAX_THROWS
      errors.add(:throws, "maximum of #{MAX_THROWS} per turn")
    end
  end
end
