class TournamentRound < ApplicationRecord
  STAGE_TYPES = %w[groups swiss playoffs].freeze
  STATUSES = %w[pending active complete].freeze

  belongs_to :tournament
  has_many :tournament_matches, dependent: :destroy

  validates :name, presence: true
  validates :stage_type, inclusion: { in: STAGE_TYPES }
  validates :status, inclusion: { in: STATUSES }
end
