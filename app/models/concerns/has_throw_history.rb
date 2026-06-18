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

  def completed_turns_for(player)
    turns
      .where(player_id: player.id)
      .where.not(completed_at: nil)
      .order(:created_at)
  end

  def turn_total_for(turn)
    turn.total_score.present? ? turn.total_score : turn.throws.sum(&:points)
  end

  def highest_turn_for(player)
    completed_turns_for(player).map { |turn| turn_total_for(turn) }.max.to_i
  end

  def first_n_turn_average(player, count: 3)
    sample = completed_turns_for(player).limit(count).to_a
    return 0.0 if sample.empty?

    (sample.sum { |turn| turn_total_for(turn) }.to_f / sample.size).round(1)
  end

  def turns_over_for(player, threshold)
    completed_turns_for(player).count { |turn| turn_total_for(turn) >= threshold }
  end

  def darts_thrown_for(player)
    all_throws_for(player).count
  end

  def throw_counts_by_multiplier(player)
    all_throws_for(player).group_by(&:multiplier).transform_values(&:count)
  end

  def per_dart_averages(player)
    buckets = { 1 => [], 2 => [], 3 => [] }

    completed_turns_for(player).find_each do |turn|
      turn.throws.order(:created_at).to_a.each_with_index do |throw, index|
        buckets[index + 1] << throw.points if buckets.key?(index + 1)
      end
    end

    buckets.transform_values do |values|
      values.empty? ? 0.0 : (values.sum.to_f / values.size).round(1)
    end
  end

  def checkout_stats_for(player)
    chances = 0
    hits = 0
    darts_used = []

    turn_summaries_for(player).each do |summary|
      chances += 1 if summary[:start_score].between?(2, 170)
    end

    legs.order(:created_at).each do |leg|
      next unless leg.winner_id == player.id

      darts_used << leg.checkout_throws if leg.checkout_throws.present?
      hits += 1 if leg.checkout_throws.present?
    end

    {
      chances: chances,
      hits: hits,
      rate: chances.zero? ? 0.0 : ((hits.to_f / chances) * 100).round(1),
      average_darts: darts_used.empty? ? 0.0 : (darts_used.sum.to_f / darts_used.size).round(1)
    }
  end

  def best_leg_for(player)
    winning_legs = legs.where(winner_id: player.id).order(:created_at)
    return nil if winning_legs.empty?

    winning_legs.min_by do |leg|
      leg.turns.where(player_id: player.id).joins(:throws).count
    end
  end

  def best_leg_darts_for(player)
    leg = best_leg_for(player)
    return nil unless leg

    leg.turns.where(player_id: player.id).joins(:throws).count
  end

  private

  def turn_summaries_for(player)
    summaries = []

    legs.order(:created_at).each do |leg|
      score = starting_score

      leg.turns.where(player_id: player.id).order(:created_at).each do |turn|
        total = turn_total_for(turn)
        summaries << { turn: turn, leg: leg, start_score: score, total: total }

        new_score = score - total
        score = if new_score < 0 || new_score == 1
          score
        elsif new_score.zero?
          0
        else
          new_score
        end
      end
    end

    summaries
  end
end
