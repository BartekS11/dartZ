class Match < ApplicationRecord
  has_many :players, dependent: :destroy
  has_many :legs, dependent: :destroy

  def start_first_leg!
    leg = legs.create!(starting_score: 501)

    leg.turns.create!(
      player: players.first,
      starting_score: 501
    )
  end

  def current_leg
    legs.where(finished_at: nil).order(:created_at).last
  end

  def finished?
    legs.exists? && legs.all?(&:finished_at)
  end
end
