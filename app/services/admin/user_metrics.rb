module Admin
  class UserMetrics
    EMPTY = {
      matches: 0, completed: 0, in_progress: 0, wins: 0, losses: 0,
      bots: 0, invitations: 0, tournaments: 0, last_match_at: nil
    }.freeze

    def self.for(users)
      users = users.to_a
      return {} if users.empty?

      user_ids = users.map(&:id)
      owned_players = Player.where(user_id: user_ids).pluck(:id, :user_id, :match_id)
      match_ids = owned_players.filter_map(&:third).uniq
      players_by_user = owned_players.group_by(&:second)
      matches = Match.where(id: match_ids).select(:id, :created_at, :finished_at, :winner_id, :invite_created_at).index_by(&:id)
      bot_match_ids = Player.where(match_id: match_ids, bot: true).distinct.pluck(:match_id).to_set
      tournament_match_ids = TournamentMatch.where(linked_match_id: match_ids).distinct.pluck(:linked_match_id).to_set

      users.index_with do |user|
        rows = players_by_user.fetch(user.id, [])
        user_player_ids = rows.map(&:first).to_set
        user_matches = rows.filter_map { |row| matches[row.third] }.uniq(&:id)
        completed = user_matches.select(&:finished_at)

        {
          matches: user_matches.size,
          completed: completed.size,
          in_progress: user_matches.count { |match| match.finished_at.nil? },
          wins: completed.count { |match| user_player_ids.include?(match.winner_id) },
          losses: completed.count { |match| !user_player_ids.include?(match.winner_id) },
          bots: user_matches.count { |match| bot_match_ids.include?(match.id) },
          invitations: user_matches.count { |match| match.invite_created_at.present? },
          tournaments: user_matches.count { |match| tournament_match_ids.include?(match.id) },
          last_match_at: user_matches.map(&:created_at).max
        }
      end
    end
  end
end
