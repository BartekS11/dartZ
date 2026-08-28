module MatchIdentifiable
  extend ActiveSupport::Concern

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
end
