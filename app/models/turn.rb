class Turn < ApplicationRecord
  belongs_to :leg
  has_many :throws, dependent: :destroy

  def remaining_score
    starting_score - throws.sum(&:points)
  end

  def busted?
    remaining_score < 0 || remaining_score == 1
  end

  def finished?
  remaining_score == 0 && throws.last&.double?
  end

  def complete!
    if finished?
      leg.update!(finished_at: Time.current)
    elsif busted?
      throws.destroy_all
    else
    leg.update!(starting_score: remaining_score)
    end
  end
end
