class LegPlayer < ApplicationRecord
  belongs_to :leg
  belongs_to :player

  validates :score, numericality: { greater_than_or_equal_to: 0 }

  def needs_double_in?
    leg.match.double_in? && !has_doubled_in?
  end

  def apply_throw!(points)
    new_score = score - points

    if new_score < 0 || new_score == 1
      raise ActiveRecord::RecordInvalid.new(self)
    end

    update!(score: new_score)
  end

  def finished?(throw)
    double_out = leg&.match&.double_out?
    double_out = true if double_out.nil?

    score == 0 && (!double_out || throw.double?)
  end
end
