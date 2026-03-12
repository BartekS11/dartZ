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

  def average_per_turn(player)
    all = all_throws_for(player)
    return 0.0 if all.empty?

    total_points = all.sum(&:points)
    total_turns  = (all.size.to_f / 3).ceil

    (total_points.to_f / total_turns).round(1)
  end

  def three_dart_average(player)
    all = all_throws_for(player)
    return 0.0 if all.empty?

    total_points = all.sum(&:points)
    total_darts  = all.size

    # Average per 3 darts
    ((total_points.to_f / total_darts) * 3).round(1)
  end
end
