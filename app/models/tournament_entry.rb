class TournamentEntry < ApplicationRecord
  STATUSES = %w[active eliminated withdrawn].freeze

  belongs_to :tournament
  belongs_to :user, optional: true

  has_many :home_matches, class_name: "TournamentMatch", foreign_key: :home_entry_id, dependent: :nullify
  has_many :away_matches, class_name: "TournamentMatch", foreign_key: :away_entry_id, dependent: :nullify
  has_many :won_matches, class_name: "TournamentMatch", foreign_key: :winner_entry_id, dependent: :nullify

  validates :name, presence: true, length: { maximum: 80 }, uniqueness: { scope: :tournament_id, case_sensitive: false }
  validates :status, inclusion: { in: STATUSES }
  validates :seed, numericality: { only_integer: true, greater_than: 0 }, allow_nil: true
  validates :wins, :draws, :losses, :points, :legs_for, :legs_against, numericality: { only_integer: true, greater_than_or_equal_to: 0 }

  before_validation :ensure_access_token

  def leg_difference
    legs_for - legs_against
  end

  private

  def ensure_access_token
    self.access_token ||= SecureRandom.hex(10)
  end
end
