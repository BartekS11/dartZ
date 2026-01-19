class LegPlayer < ApplicationRecord
  belongs_to :leg
  belongs_to :player

  validates :score, numericality: { greater_than_or_equal_to: 0 }

  def apply_throw!(points)
    new_score = score - points

    # bust rules
    if new_score < 0 || new_score == 1
      raise ActiveRecord::RecordInvalid.new(self)
    end

    update!(score: new_score)
  end

  def finished?(throw)
    score == 0 && throw.double?
  end
end
