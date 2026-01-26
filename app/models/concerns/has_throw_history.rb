module HasThrowHistory
  extend ActiveSupport::Concern

  def last_throws_for(player, limit: 3)
    throws
      .joins(:turn)
      .where(turns: { player_id: player.id })
      .order(created_at: :desc)
      .limit(limit)
  end

  def all_throws_for(player)
    throws
      .joins(:turn)
      .where(turns: { player_id: player.id })
      .order(created_at: :desc)
  end
end
