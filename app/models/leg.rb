class Leg < ApplicationRecord
  belongs_to :match
  has_many :turns, dependent: :destroy

  def current_turn
    turns.order(:created_at).last ||
      turns.create!(
        player: match.players.first,
        starting_score: starting_score
      )
  end

  def start_next_turn!
    current_index = players.index(current_turn.player)
    next_player = players[(current_index + 1) % players.size]

    turns.create!(
      player: next_player,
      starting_score: starting_score
    )
  end

  def active_player
    current_turn.player
  end
end
