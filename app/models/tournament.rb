class Tournament < ApplicationRecord
  FORMATS = %w[groups swiss playoffs groups_playoffs swiss_playoffs].freeze
  VISIBILITIES = %w[public_guest participant_only].freeze
  STATUSES = %w[draft active complete archived].freeze
  SEEDING_MODES = %w[auto manual].freeze
  PLAYOFF_MODES = %w[single_elimination double_elimination].freeze

  include HasPublicId
  public_id_prefix "t_"

  include X01GameSettings
  include TournamentInitialization
  include TournamentGameSettings
  include TournamentStages
  include TournamentAccessPolicy
  include TournamentStandings
  include TournamentLiveUpdates

  belongs_to :owner_user, class_name: "User", optional: true

  has_many :entries, class_name: "TournamentEntry", dependent: :destroy
  has_many :rounds, class_name: "TournamentRound", dependent: :destroy
  has_many :tournament_matches, dependent: :destroy

  validates :title, presence: true, length: { maximum: 100 }
  validates :format_type, inclusion: { in: FORMATS }
  validates :visibility, inclusion: { in: VISIBILITIES }
  validates :status, inclusion: { in: STATUSES }
  validates :seeding_mode, inclusion: { in: SEEDING_MODES }
  validates :playoff_mode, inclusion: { in: PLAYOFF_MODES }
  validates :best_of_legs, :best_of_sets, numericality: { only_integer: true, greater_than: 0, less_than_or_equal_to: 99 }
  validates :playoff_best_of_legs, :playoff_best_of_sets, :semifinal_best_of_legs, :final_best_of_legs, numericality: { only_integer: true, greater_than: 0, less_than_or_equal_to: 99 }, allow_nil: true
  validates :starting_score, inclusion: { in: Match::X01_STARTING_SCORES }
  validates :playoff_starting_score, inclusion: { in: Match::X01_STARTING_SCORES }, allow_nil: true
  validates :double_in, :double_out, inclusion: { in: [ true, false ] }
  validates :playoff_double_in, :playoff_double_out, inclusion: { in: [ true, false ] }, allow_nil: true
  validates :group_count, :swiss_round_count, :playoff_qualifier_count, :qualifiers_per_group, numericality: { only_integer: true, greater_than: 0, less_than_or_equal_to: 256 }, allow_nil: true

  scope :guest_public, -> { where(owner_user_id: nil, visibility: "public_guest") }
  scope :owned_by, ->(user) { where(owner_user: user) }
end
