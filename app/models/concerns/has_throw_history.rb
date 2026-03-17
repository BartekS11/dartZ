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
    # Use all legs for finished matches, current leg for active matches
    legs_to_check = finished? ? legs : [ current_leg ].compact

    completed_turns = legs_to_check.flat_map do |leg|
      leg.turns
         .where(player_id: player.id)
         .where.not(completed_at: nil)
         .to_a
    end

    return 0.0 if completed_turns.blank?

    total_points = completed_turns.sum do |turn|
      turn.total_score.present? ? turn.total_score : turn.throws.sum(&:points)
    end

    (total_points.to_f / completed_turns.size).round(1)
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
