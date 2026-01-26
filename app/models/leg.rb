class Leg < ApplicationRecord
  include LegFlow

  belongs_to :match
  has_many :leg_players, dependent: :destroy
  has_many :players, through: :leg_players
  has_many :turns, dependent: :destroy

  after_create :init_players

  def ensure_current_turn!
    turn = turns.order(:created_at).last
    return turn if turn.present? && !turn.completed?

    start_next_turn!
  end

  def current_turn
    turns.order(:created_at).last
  end

  def start_first_turn!
    turns.create!(player: first_player)
  end

  def active_player
    current_turn&.player
  end

  def finished?
    finished_at.present?
  end

  def finish!
    match.finish!
  end

  def first_player
    leg_players.order(:created_at).first.player
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
