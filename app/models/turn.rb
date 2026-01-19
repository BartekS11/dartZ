class Turn < ApplicationRecord
  MAX_THROWS = 3

  belongs_to :leg
  belongs_to :player
  has_many :throws, dependent: :destroy

  def leg_player
    leg.leg_players.find_by!(player: player)
  end

  def turn_points
    throws.sum(&:points)
  end

  def busted?
    new_score < 0 || new_score == 1
  end

  def finished?
    new_score == 0 && throws.last&.double?
  end

  def complete?
    throws.size >= MAX_THROWS || busted? || finished?
  end

  def complete!
    lp = leg_player

    if finished?
      lp.update!(score: 0)
      leg.update!(finished_at: Time.current)
    elsif busted?
      # DO NOTHING → score stays the same
    else
      lp.update!(score: new_score)
    end

    leg.start_next_turn! unless finished?
  end

  private

  def new_score
    leg_player.score - turn_points
  end
end
