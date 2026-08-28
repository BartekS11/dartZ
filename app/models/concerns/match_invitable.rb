module MatchInvitable
  extend ActiveSupport::Concern

  INVITE_TTL = 24.hours

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
end
