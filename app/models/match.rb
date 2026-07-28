class Match < ApplicationRecord
  X01_STARTING_SCORES = [ 101, 201, 301, 401, 501, 601, 701 ].freeze

  before_destroy :destroy_direct_legs

  include MatchLifecycle
  include HasThrowHistory
  include HasUndoSupport

  has_many :players,  dependent: :destroy
  has_many :match_sets, dependent: :destroy, class_name: "MatchSet"
  has_many :legs,     through: :match_sets
  has_many :turns,    through: :legs
  has_many :throws,   through: :turns

  validates :match_identifier, uniqueness: true, allow_blank: true
  validates :guest_token, uniqueness: true, allow_blank: true
  validates :best_of_legs, :best_of_sets, numericality: { only_integer: true, greater_than: 0, less_than_or_equal_to: 99 }
  validates :starting_score, inclusion: { in: X01_STARTING_SCORES }
  validates :double_in, :double_out, inclusion: { in: [ true, false ] }
  validates :invite_token, uniqueness: true, allow_blank: true

  INVITE_TTL = 24.hours

  def game_mode_labels
    labels = [ starting_score.to_s ]
    labels << "Double in" if double_in?
    labels << "Double out" if double_out?
    labels
  end

  def invite_match?
    invite_token.present?
  end

  def invite_pending?
    invite_match? && invite_joined_at.blank? && invite_cancelled_at.blank? && !invite_expired?
  end

  def invite_expired?
    invite_expires_at.present? && Time.current > invite_expires_at
  end

  def invite_cancelled?
    invite_cancelled_at.present?
  end

  def invite_full?
    invite_joined_at.present? || players.offset(1).exists?
  end

  def invite_joinable?
    invite_pending? && !invite_full?
  end

  def ensure_invite_token!
    return invite_token if invite_token.present?

    loop do
      self.invite_token = SecureRandom.urlsafe_base64(32)
      break unless Match.where(invite_token: invite_token).where.not(id: id).exists?
    end

    self.invite_created_at ||= Time.current
    self.invite_expires_at ||= invite_created_at + INVITE_TTL
    save! if persisted?
    invite_token
  end

  def cancel_invite!
    update!(invite_cancelled_at: Time.current)
  end

  def ensure_guest_token!
    return guest_token if guest_token.present?

    loop do
      self.guest_token = SecureRandom.hex(24)
      break unless Match.where(guest_token: guest_token).where.not(id: id).exists?
    end

    update!(guest_token: guest_token) if persisted?
    guest_token
  end

  def display_identifier
    match_identifier.presence || "##{id}"
  end

  def ui_identifier
    return "Match ##{id}" if match_identifier.blank?

    parts = match_identifier.split("-")
    suffix = parts.last
    date_token = parts[-2]

    date_label = begin
      Date.strptime(date_token, "%Y%m%d").strftime("%d %b")
    rescue StandardError
      date_token
    end

    label = if match_identifier.start_with?("GUEST-")
      "Guest"
    elsif match_identifier.start_with?("USER-")
      "You"
    elsif match_identifier.start_with?("MULTIUSER-")
      "Shared"
    else
      "Match"
    end

    "#{label} · #{date_label} · #{suffix}"
  end

  def ensure_match_identifier!
    return match_identifier if match_identifier.present?

    generate_match_identifier
    update!(match_identifier: match_identifier) if persisted?
    match_identifier
  end

  def winner
    return nil unless finished?
    match_sets.order(:created_at).last
              &.legs&.order(:created_at)&.last
              &.winner
  end

  def ensure_current_leg!
    leg = legs.order(:created_at).last
    return leg if leg.present? && !leg.finished?

    start_first_leg!
  end

  def start_first_leg!
    leg = legs.create!

    players.each do |player|
      leg.leg_players.find_or_create_by!(
        player: player
      ) do |lp|
        lp.score = starting_score
        lp.starting_score = starting_score if lp.respond_to?(:starting_score=)
        lp.has_doubled_in = !double_in? if lp.respond_to?(:has_doubled_in=)
      end
    end

    leg.start_first_turn!
    leg
  end

  def current_leg
    legs.where(finished_at: nil).order(:created_at).last
  end

  def current_player
    current_leg&.current_turn&.player
  end

  def next_player_after(player)
    ordered = players.order(:created_at).to_a
    idx     = ordered.index(player)
    ordered[(idx + 1) % ordered.size]
  end

  def score_for(player)
    return starting_score unless current_leg
    current_leg.leg_players.find_by(player: player)&.score || starting_score
  end

  def subtract_score!(player, points)
    current = score_for(player)
    new_score = current - points

    # Escape on bulk
    return if new_score < 0

    update_score_for(player, new_score)
  end

  private

  def generate_match_identifier
    loop do
      identifier = build_match_identifier
      self.match_identifier = identifier
      break identifier unless Match.where(match_identifier: identifier).where.not(id: id).exists?
    end
  end

  def build_match_identifier
    user_ids = players.map(&:user_id).compact.uniq
    scope = if user_ids.empty?
      "GUEST"
    elsif user_ids.one?
      "USER-#{user_ids.first}"
    else
      "MULTIUSER-#{user_ids.max}"
    end

    timestamp = Time.zone.respond_to?(:now) ? Time.zone.now : Time.zone
    date = timestamp.strftime("%Y%m%d")
    suffix = SecureRandom.hex(3).upcase

    "#{scope}-#{date}-#{suffix}"
  end

  def destroy_direct_legs
    Leg.where(match_id: id).find_each(&:destroy!)
  end
end
