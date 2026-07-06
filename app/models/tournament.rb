class Tournament < ApplicationRecord
  FORMATS = %w[groups swiss playoffs groups_playoffs swiss_playoffs].freeze
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
  validates :playoff_best_of_legs, :playoff_best_of_sets, :semifinal_best_of_legs, :final_best_of_legs, numericality: { only_integer: true, greater_than: 0, less_than_or_equal_to: 99 }, allow_nil: true
  validates :starting_score, inclusion: { in: Match::X01_STARTING_SCORES }
  validates :playoff_starting_score, inclusion: { in: Match::X01_STARTING_SCORES }, allow_nil: true
  validates :double_in, :double_out, inclusion: { in: [ true, false ] }
  validates :playoff_double_in, :playoff_double_out, inclusion: { in: [ true, false ] }, allow_nil: true
  validates :group_count, :swiss_round_count, :playoff_qualifier_count, :qualifiers_per_group, numericality: { only_integer: true, greater_than: 0, less_than_or_equal_to: 256 }, allow_nil: true

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

  def playoff_game_settings
    {
      starting_score: playoff_starting_score || starting_score,
      double_in: playoff_double_in.nil? ? double_in : playoff_double_in,
      double_out: playoff_double_out.nil? ? double_out : playoff_double_out
    }
  end

  def group_match_settings
    { best_of_legs: best_of_legs, best_of_sets: best_of_sets, **game_settings }
  end

  def playoff_match_settings(round_role: nil)
    legs = case round_role
    when :semifinal then semifinal_best_of_legs.presence || playoff_best_of_legs
    when :final then final_best_of_legs.presence || playoff_best_of_legs
    else playoff_best_of_legs
    end

    { best_of_legs: legs || best_of_legs, best_of_sets: playoff_best_of_sets || best_of_sets, **playoff_game_settings }
  end

  def playoff_match_settings_for_entries(entries_count, bracket: nil)
    role = if bracket == "final" || entries_count == 2
      :final
    elsif entries_count == 4
      :semifinal
    end

    playoff_match_settings(round_role: role)
  end

  def playoff_enabled?
    format_type.in?(%w[groups playoffs groups_playoffs swiss_playoffs])
  end

  def group_stage_enabled?
    format_type.in?(%w[groups groups_playoffs])
  end

  def swiss_stage_enabled?
    format_type.in?(%w[swiss swiss_playoffs])
  end

  def combined_with_playoffs?
    format_type.in?(%w[groups groups_playoffs swiss_playoffs])
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

  def can_view?(user: nil, admin_token: nil, participant_token: nil, join_token: nil, share_token: nil)
    return true if can_administer?(user:, admin_token:)
    return true if visibility == "public_guest"
    return true if token_matches?(share_token, self.share_token)
    return true if owner_user.present? && participant?(user)
    return true if participant_token.present? && entries.exists?(access_token: participant_token)
    return true if token_matches?(join_token, self.join_token)

    false
  end

  def standings
    entries.to_a.sort_by do |entry|
      [ -entry.wins, -entry.leg_difference, -(swiss_stage_enabled? ? entry.buchholz.to_f : entry.points), -entry.points, entry.name.downcase ]
    end
  end

  def group_names
    entries.where.not(group_name: [ nil, "" ]).distinct.order(:group_name).pluck(:group_name)
  end

  def standings_for_group(group_name)
    entries.where(group_name: group_name).to_a.sort_by do |entry|
      [ -entry.wins, -entry.leg_difference, -entry.points, entry.name.downcase ]
    end
  end

  def qualifiers_per_group_value
    qualifiers_per_group.presence || begin
      groups = [ group_names.size, 1 ].max
      count = playoff_qualifier_count.presence || groups * 2
      [ (count.to_f / groups).ceil, 1 ].max
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
    return false unless swiss_stage_enabled?
    return false if next_swiss_round_number > effective_swiss_round_count

    last_round = swiss_rounds.last
    return true if last_round.nil?

    last_round.tournament_matches.exists? && last_round.tournament_matches.where.not(status: "complete").none?
  end

  def can_generate_next_playoff_round?
    return false unless playoff_enabled?

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
    Turbo::StreamsChannel.broadcast_replace_to(
      [ self, :live ],
      target: "tournament-live-board",
      partial: "tournaments/live_board",
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
    self.playoff_best_of_legs ||= best_of_legs
    self.playoff_best_of_sets ||= best_of_sets
    self.semifinal_best_of_legs ||= playoff_best_of_legs || best_of_legs
    self.final_best_of_legs ||= playoff_best_of_legs || best_of_legs
    self.playoff_starting_score ||= starting_score
    self.playoff_double_in = double_in if playoff_double_in.nil?
    self.playoff_double_out = double_out if playoff_double_out.nil?
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
