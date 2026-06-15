class TournamentMatch < ApplicationRecord
  STATUSES = %w[pending live complete].freeze
  SOURCES = %w[generated manual].freeze

  belongs_to :tournament
  belongs_to :tournament_round
  belongs_to :home_entry, class_name: "TournamentEntry", optional: true
  belongs_to :away_entry, class_name: "TournamentEntry", optional: true
  belongs_to :winner_entry, class_name: "TournamentEntry", optional: true
  belongs_to :linked_match, class_name: "Match", optional: true

  validates :status, inclusion: { in: STATUSES }
  validates :source, inclusion: { in: SOURCES }

  def label
    [home_entry&.name || "TBD", away_entry&.name || "TBD"].join(" vs ")
  end

  def launchable?
    home_entry.present? && away_entry.present? && linked_match.blank?
  end

  def sync_from_linked_match!
    return unless linked_match&.finished?
    return if status == "complete"

    winner_name = linked_match.winner&.display_name
    self.winner_entry = [home_entry, away_entry].find { |entry| entry&.name == winner_name }
    self.home_legs = linked_match.legs.where(winner_id: linked_match.players.find_by(name: home_entry&.name)&.id).count
    self.away_legs = linked_match.legs.where(winner_id: linked_match.players.find_by(name: away_entry&.name)&.id).count
    self.status = "complete"
    self.completed_at = linked_match.finished_at || Time.current
    save!
  end
end
