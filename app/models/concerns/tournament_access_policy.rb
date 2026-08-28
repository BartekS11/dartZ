module TournamentAccessPolicy
  extend ActiveSupport::Concern

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

  private

  def token_matches?(provided, expected)
    return false if provided.blank? || expected.blank? || provided.bytesize != expected.bytesize

    ActiveSupport::SecurityUtils.secure_compare(provided, expected)
  end
end
