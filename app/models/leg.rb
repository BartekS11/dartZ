class Leg < ApplicationRecord
  belongs_to :match
  has_many :leg_players, dependent: :destroy
  has_many :players, through: :leg_players
  has_many :turns, dependent: :destroy

  after_create :init_players

  def current_turn
    turns.order(:created_at).last
  end

  def active_player
    current_turn&.player
  end

  def start_next_turn!
    players = match.players.to_a
    current = current_turn.player
    next_player = players[(players.index(current) + 1) % players.size]

    turns.create!(player: next_player)
  end

  private

  def init_players
    match.players.find_each do |player|
      leg_players.create!(player: player, score: 501)
    end
  end
end

