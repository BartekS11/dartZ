module HasThrowHistory
  extend ActiveSupport::Concern

  def last_throws_for(player, limit: 3)
    return Throw.none unless current_leg

    throws
      .joins(:turn)
      .where(turns: { player_id: player.id, leg_id: current_leg.id })
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

  def last_turn_throws_for(player)
    current = current_leg
    return [] unless current

    # Active turn with throws first
    active_turn = current.turns
                         .where(player_id: player.id, completed_at: nil)
                         .joins(:throws)
                         .order(created_at: :desc)
                         .first

    return active_turn.throws.order(:created_at).to_a if active_turn

    # Last completed turn in current leg
    last_completed = current.turns
                            .joins(:throws)
                            .where(turns: { player_id: player.id })
                            .where.not(turns: { completed_at: nil })
                            .order("turns.completed_at DESC")
                            .first

    return [] unless last_completed
    last_completed.throws.order(:created_at).to_a
  end
end
