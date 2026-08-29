class TournamentMatch < ApplicationRecord
  STATUSES = %w[pending live complete].freeze
  SOURCES = %w[generated manual].freeze

  include HasPublicId
  public_id_prefix "tm_"

  include X01GameSettings

  belongs_to :tournament
  belongs_to :tournament_round
  belongs_to :home_entry, class_name: "TournamentEntry", optional: true
  belongs_to :away_entry, class_name: "TournamentEntry", optional: true
  belongs_to :winner_entry, class_name: "TournamentEntry", optional: true
  belongs_to :linked_match, class_name: "Match", optional: true

  validates :status, inclusion: { in: STATUSES }
  validates :source, inclusion: { in: SOURCES }
  validates :best_of_legs, :best_of_sets, numericality: { only_integer: true, greater_than: 0, less_than_or_equal_to: 99 }
  validates :starting_score, inclusion: { in: Match::X01_STARTING_SCORES }
  validates :double_in, :double_out, inclusion: { in: [ true, false ] }
  validates :home_sets, :away_sets, :home_legs, :away_legs, numericality: { only_integer: true, greater_than_or_equal_to: 0 }

  def label
    [ home_entry&.name || "TBD", away_entry&.name || "TBD" ].join(" vs ")
  end

  def launchable?
    status == "pending" && home_entry.present? && away_entry.present? && linked_match.blank?
  end

  def sync_from_linked_match!
    return unless linked_match&.finished?
    return if status == "complete"

    winner_name = linked_match.winner&.display_name
    self.winner_entry = [ home_entry, away_entry ].find { |entry| entry&.name == winner_name }
    home_player = linked_match.players.find_by(name: home_entry&.name)
    away_player = linked_match.players.find_by(name: away_entry&.name)
    self.home_sets = linked_match.match_sets.where(winner_id: home_player&.id).count
    self.away_sets = linked_match.match_sets.where(winner_id: away_player&.id).count
    self.home_legs = linked_match.legs.where(winner_id: home_player&.id).count
    self.away_legs = linked_match.legs.where(winner_id: away_player&.id).count
    self.status = "complete"
    self.completed_at = linked_match.finished_at || Time.current
    save!
  end
end
