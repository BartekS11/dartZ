class MatchAccess
  def initialize(match:, user: nil, guest_token: nil, guest_id: nil)
    @match = match
    @user = user
    @guest_token = guest_token
    @guest_id = guest_id
  end

  def allowed?
    user_player? || valid_guest_token? || valid_guest_id?
  end

  private

  attr_reader :match, :user, :guest_token, :guest_id

  def user_player?
    user.present? && match.players.exists?(user_id: user.id)
  end

  def valid_guest_token?
    secure_token_match?(guest_token, match.guest_token)
  end

  def valid_guest_id?
    guest_id.present? && match.guest_id.present? && guest_id == match.guest_id
  end

  def secure_token_match?(provided, expected)
    return false if provided.blank? || expected.blank? || provided.bytesize != expected.bytesize

    ActiveSupport::SecurityUtils.secure_compare(provided, expected)
  end
end
