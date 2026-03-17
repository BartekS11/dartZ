class MatchSet < ApplicationRecord
  include SetFlow

  belongs_to :match
  has_many :legs, dependent: :destroy
  has_many :turns, through: :legs
  has_many :throws, through: :turns

  def finished?
    finished_at.present?
  end

  def winner
    return nil unless finished?
    match.players.find_by(id: winner_id)
  end

  def legs_needed_to_win
    (match.best_of_legs / 2.0).ceil
  end

  def legs_won_by(player)
    legs.where(winner_id: player.id).count
  end

  def finish!(winner)
    update!(finished_at: Time.current, winner_id: winner.id)
    match.on_set_finished!(winner)
  end

  def current_leg
    legs.where(finished_at: nil).order(:created_at).last
  end
  def duration_minutes
    return nil unless finished?
    ((finished_at - created_at) / 60).round
  end

  def duration_display
    return nil unless finished?
    total = (finished_at - created_at).to_i
    mins  = total / 60
    secs  = total % 60
    format("%d:%02d", mins, secs)
  end

  def start_first_leg!
    leg = legs.create!(match: match)
    leg.start_first_turn!
    leg
  end

  def start_next_leg!
    leg = legs.create!(match: match)
    leg.start_first_turn!
    leg
  end
end
