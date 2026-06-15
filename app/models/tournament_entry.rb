class TournamentEntry < ApplicationRecord
  STATUSES = %w[active eliminated withdrawn].freeze

  belongs_to :tournament
  belongs_to :user, optional: true

  has_many :home_matches, class_name: "TournamentMatch", foreign_key: :home_entry_id, dependent: :nullify
  has_many :away_matches, class_name: "TournamentMatch", foreign_key: :away_entry_id, dependent: :nullify
  has_many :won_matches, class_name: "TournamentMatch", foreign_key: :winner_entry_id, dependent: :nullify

  validates :name, presence: true, uniqueness: { scope: :tournament_id, case_sensitive: false }
  validates :status, inclusion: { in: STATUSES }

  before_validation :ensure_access_token

  def leg_difference
    legs_for - legs_against
  end

  private

  def ensure_access_token
    self.access_token ||= SecureRandom.hex(10)
  end
end
