class Turn < ApplicationRecord
  MAX_THROWS = 3

  belongs_to :leg
  belongs_to :player
  has_many :throws, dependent: :destroy

  def leg_player
    leg.leg_players.find_by!(player: player)
  end

def apply_throw!(throw)
  lp = leg_player
  starting_score = lp.score
  new_score = starting_score - throw.points

  # BUST
  if new_score < 0 || new_score == 1
    lp.update!(score: starting_score) # restore
    complete_turn!
    return
  end

  # FINISH
  if new_score == 0
    if throw.double?
      lp.update!(score: 0)
      leg.finish!
    else
      lp.update!(score: starting_score)
    end

    complete_turn!
    return
  end

  lp.update!(score: new_score)

  complete_turn! if throws.count >= MAX_THROWS
end

  def completed?
    completed_at.present?
  end

  private

  def complete_turn!
    return if completed?

    update!(completed_at: Time.current)
    leg.start_next_turn!
  end
end
