class Match < ApplicationRecord
  belongs_to :player
  has_many :legs, dependent: :destroy

  STARTING_SCORE = 501

  def current_leg
    legs.order(:created_at).last ||
      legs.create!(starting_score: STARTING_SCORE)
  end

  def finished?
    current_leg.finished_at.present?
  end
end
