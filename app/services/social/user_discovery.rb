module Social
  class UserDiscovery
    def self.call(viewer:, query:)
      query = query.to_s.strip
      return User.none if query.blank?

      normalized_code = query.delete("- ").upcase
      scope = User.where(friend_share_code: normalized_code)
      scope = scope.or(User.where(discoverable_by_nickname: true).where("LOWER(nickname) = ?", query.downcase))
      blocked_by_viewer = UserBlock.where(blocker: viewer).select(:blocked_id)
      blocking_viewer = UserBlock.where(blocked: viewer).select(:blocker_id)
      scope.where.not(id: viewer.id)
        .where.not(id: blocked_by_viewer)
        .where.not(id: blocking_viewer)
        .order(:nickname, :public_id)
    end
  end
end
