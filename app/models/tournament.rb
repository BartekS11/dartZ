class Tournament < ApplicationRecord
  FORMATS = %w[groups swiss playoffs].freeze
  VISIBILITIES = %w[public_guest participant_only].freeze
  STATUSES = %w[draft active complete archived].freeze
  SEEDING_MODES = %w[auto manual].freeze
  PLAYOFF_MODES = %w[single_elimination double_elimination].freeze

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
  validates :starting_score, inclusion: { in: Match::X01_STARTING_SCORES }
  validates :double_in, :double_out, inclusion: { in: [ true, false ] }
  validates :group_count, :swiss_round_count, :playoff_qualifier_count, numericality: { only_integer: true, greater_than: 0, less_than_or_equal_to: 256 }, allow_nil: true

  before_validation :assign_defaults
  before_validation :ensure_tokens

  scope :guest_public, -> { where(owner_user_id: nil, visibility: "public_guest") }
  scope :owned_by, ->(user) { where(owner_user: user) }

  def game_mode_labels
    labels = [ starting_score.to_s ]
    labels << "Double in" if double_in?
    labels << "Double out" if double_out?
    labels
  end

  def game_settings
    { starting_score: starting_score, double_in: double_in, double_out: double_out }
  end

  def guest_owned?
    owner_user_id.nil?
  end

  def participant_only?
    visibility == "participant_only"
  end

  def published?
    published_at.present?
  end

  def participants_for(user)
    return TournamentEntry.none unless user

    entries.where(user: user)
  end

  def participant?(user)
    participants_for(user).exists?
  end

  def can_administer?(user: nil, admin_token: nil)
    return true if owner_user.present? && user == owner_user
    return true if guest_owned? && token_matches?(admin_token, self.admin_token)

    false
  end

  def can_view?(user: nil, admin_token: nil, participant_token: nil, join_token: nil)
    return true if can_administer?(user:, admin_token:)
    return true if visibility == "public_guest"
    return true if owner_user.present? && participant?(user)
    return true if participant_token.present? && entries.exists?(access_token: participant_token)
    return true if token_matches?(join_token, self.join_token)

    false
  end

  def standings
    entries.to_a.sort_by do |entry|
      [ -entry.wins, -entry.leg_difference, -(format_type == "swiss" ? entry.buchholz.to_f : entry.points), -entry.points, entry.name.downcase ]
    end
  end

  def effective_swiss_round_count
    swiss_round_count.presence || [ Math.log2([ entries.count, 2 ].max).ceil, 1 ].max
  end

  def swiss_rounds
    rounds.where(stage_type: "swiss").order(:number)
  end

  def next_swiss_round_number
    swiss_rounds.maximum(:number).to_i + 1
  end

  def can_generate_next_swiss_round?
    return false unless format_type == "swiss"
    return false if next_swiss_round_number > effective_swiss_round_count

    last_round = swiss_rounds.last
    return true if last_round.nil?

    last_round.tournament_matches.exists? && last_round.tournament_matches.where.not(status: "complete").none?
  end

  def can_generate_next_playoff_round?
    return false unless format_type == "playoffs"

    rounds.where(stage_type: "playoffs").where.not(status: "complete").none?
  end

  def sync_from_linked_matches!
    tournament_matches.includes(:linked_match).find_each(&:sync_from_linked_match!)
    TournamentProgressor.new(self).call
  end

  def broadcast_live_update!(can_admin: false, admin_token: nil)
    Turbo::StreamsChannel.broadcast_replace_to(
      [ self, :live ],
      target: "tournament-live-panels",
      partial: "tournaments/live_panels",
      locals: { tournament: self, can_admin: can_admin, admin_token: admin_token }
    )
  end

  private

  def assign_defaults
    self.visibility = if owner_user.present?
      "participant_only"
    elsif visibility.blank?
      "public_guest"
    else
      visibility
    end
    self.playoff_mode = "single_elimination" if playoff_mode.blank?
    self.seeding_mode = "auto" if seeding_mode.blank?
    self.status = "draft" if status.blank?
  end

  def ensure_tokens
    self.share_token ||= SecureRandom.hex(8)
    self.admin_token ||= SecureRandom.hex(16)
    self.join_token ||= SecureRandom.hex(6)
  end

  def token_matches?(provided, expected)
    return false if provided.blank? || expected.blank? || provided.bytesize != expected.bytesize

    ActiveSupport::SecurityUtils.secure_compare(provided, expected)
  end
end
