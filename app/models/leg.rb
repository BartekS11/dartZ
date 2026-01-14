class Leg < ApplicationRecord
  belongs_to :match
  has_many :turns, dependent: :destroy

  def current_turn
    turns.order(:created_at).last ||
      turns.create!(starting_score: starting_score)
  end
end
