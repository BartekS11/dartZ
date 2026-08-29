class MatchSet < ApplicationRecord
  include SetFlow
  include HasDurationDisplay

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
  def start_first_leg!(starter = nil)
    start_leg!(starter)
  end

  def start_next_leg!
    start_leg!
  end

  private

  def start_leg!(starter = nil)
    starter ||= next_leg_starter
    leg = legs.create!(match: match)
    leg.start_first_turn!(starter)
    leg
  end

  def next_leg_starter
    ordered_players = match.players.order(:created_at).to_a
    return nil if ordered_players.empty?

    first_starter_index = (match.starting_player_position.to_i - 1).clamp(0, ordered_players.size - 1)
    ordered_players[(first_starter_index + match.legs.count) % ordered_players.size]
  end
end
