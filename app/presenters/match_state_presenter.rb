class MatchStatePresenter
  attr_reader :match

  def initialize(match)
    @match = match
    preload!
  end

  def players
    @players
  end

  def current_set
    @current_set
  end

  def current_leg
    @current_leg
  end

  def current_turn
    @current_turn
  end

  def current_player
    @players_by_id[@current_turn&.player_id]
  end

  def winner
    @players_by_id[@winner_id]
  end

  def finished?
    match.finished?
  end

  def score_for(player)
    player_state(player)[:score]
  end

  def three_dart_average(player)
    player_state(player)[:avg]
  end

  def sets_won_by(player)
    player_state(player)[:sets_won]
  end

  def legs_won_by(player)
    player_state(player)[:legs_won]
  end

  def last_turn_throws_for(player)
    player_state(player)[:last_turn_throws]
  end

  def last_turn_total_for(player)
    turn = player_state(player)[:stats][:last_completed_turn_in_current_leg]
    return nil unless turn

    turn_total_for(turn)
  end

  def last_throws_for(player, limit: 3)
    player_state(player)[:last_throws].first(limit)
  end

  def needs_double_in?(player)
    return false unless match.double_in? && current_leg

    current_leg.leg_players.find { |leg_player| leg_player.player_id == player_key(player) }&.needs_double_in? || false
  end

  def stats_for(player)
    player_state(player)[:stats]
  end

  def average_per_turn(player)
    player_state(player)[:stats][:average_per_turn]
  end

  def turn_total(turn)
    turn_total_for(turn)
  end

  def leg_number_for(leg)
    @leg_position[leg.id]
  end

  def summary_payload
    {
      id: match.id,
      match_identifier: match.match_identifier,
      ui_identifier: match.ui_identifier,
      finished: finished?,
      starting_score: match.starting_score,
      game_mode_labels: match.game_mode_labels,
      players: players.map { |player| summary_player_payload(player) }
    }
  end

  def state_payload
    {
      id: match.id,
      match_identifier: match.match_identifier,
      ui_identifier: match.ui_identifier,
      finished: finished?,
      best_of_legs: match.best_of_legs,
      best_of_sets: match.best_of_sets,
      starting_score: match.starting_score,
      double_in: match.double_in?,
      double_out: match.double_out?,
      winner: winner&.display_name,
      current_player: current_player&.display_name,
      current_turn_id: current_turn&.id,
      players: players.map { |player| state_player_payload(player) }
    }
  end

  private

  def preload!
    @players = match.players.includes(:user).order(:created_at).to_a
    @players_by_id = @players.index_by(&:id)

    @match_sets = match.match_sets.includes(legs: [ { turns: :throws }, { leg_players: :player } ]).order(:created_at).to_a
    @current_set = @match_sets.reverse.find { |match_set| match_set.finished_at.nil? }
    @current_leg = @current_set&.legs&.to_a&.sort_by(&:created_at)&.reverse&.find { |leg| leg.finished_at.nil? }
    @current_turn = @current_leg&.turns&.to_a&.max_by(&:created_at)
    @winner_id = winning_player_id

    build_indexes!
    build_player_states!
  end

  def build_indexes!
    @turn_totals = {}
    @all_completed_turns = Hash.new { |hash, key| hash[key] = [] }
    @current_leg_completed_turns = Hash.new { |hash, key| hash[key] = [] }
    @all_throws = Hash.new { |hash, key| hash[key] = [] }
    @current_leg_throws = Hash.new { |hash, key| hash[key] = [] }
    @winning_legs = Hash.new { |hash, key| hash[key] = [] }
    @leg_position = {}
    @sets_won = Hash.new(0)
    @legs_won = Hash.new(0)
    @scores = Hash.new(match.starting_score)
    @active_turns = {}
    @last_completed_turns_in_current_leg = {}

    @match_sets.each do |match_set|
      @sets_won[match_set.winner_id] += 1 if match_set.winner_id
    end

    display_set = @current_set || @match_sets.last
    legs = @match_sets.flat_map(&:legs).sort_by(&:created_at)

    legs.each_with_index do |leg, index|
      @leg_position[leg.id] = index + 1
      @winning_legs[leg.winner_id] << leg if leg.winner_id
      @legs_won[leg.winner_id] += 1 if display_set && leg.match_set_id == display_set.id && leg.winner_id

      if @current_leg && leg.id == @current_leg.id
        leg.leg_players.each do |leg_player|
          @scores[leg_player.player_id] = leg_player.score || match.starting_score
        end
      end

      turns = leg.turns.to_a.sort_by(&:created_at)
      turns.each do |turn|
        throws = turn.throws.to_a.sort_by(&:created_at)
        @all_throws[turn.player_id].concat(throws)

        if @current_leg && leg.id == @current_leg.id
          @current_leg_throws[turn.player_id].concat(throws)
          if turn.completed_at.present?
            @current_leg_completed_turns[turn.player_id] << turn
            @last_completed_turns_in_current_leg[turn.player_id] = turn
          elsif throws.any?
            @active_turns[turn.player_id] = turn
          end
        end

        next if turn.completed_at.blank?

        @all_completed_turns[turn.player_id] << turn
        @turn_totals[turn.id] = turn.total_score.presence || throws.sum(&:points)
      end
    end
  end

  def build_player_states!
    @player_states = {}

    players.each do |player|
      player_id = player.id
      completed_turns = @all_completed_turns[player_id]
      avg_turns = finished? ? completed_turns : @current_leg_completed_turns[player_id]
      active_turn = @active_turns[player_id]
      last_completed_turn = @last_completed_turns_in_current_leg[player_id]
      last_turn_throws = if active_turn
        active_turn.throws.to_a.sort_by(&:created_at)
      elsif last_completed_turn
        last_completed_turn.throws.to_a.sort_by(&:created_at)
      else
        []
      end
      last_turn_throw_ids = last_turn_throws.map(&:id)
      recent_current_leg_throws = @current_leg_throws[player_id].sort_by(&:created_at).reverse
      split = @all_throws[player_id].each_with_object(Hash.new(0)) do |throw, counts|
        counts[throw.multiplier] += 1
      end

      @player_states[player_id] = {
        score: @scores.fetch(player_id, match.starting_score),
        avg: average_for(avg_turns),
        sets_won: @sets_won[player_id],
        legs_won: @legs_won[player_id],
        last_turn_throws: last_turn_throws,
        last_throws: recent_current_leg_throws,
        stats: {
          completed_turns: completed_turns,
          darts_thrown: @all_throws[player_id].size,
          average_per_turn: average_per_turn_for(player_id, completed_turns),
          highest_turn: completed_turns.map { |turn| turn_total_for(turn) }.max.to_i,
          first_nine_avg: average_for(completed_turns.first(3)),
          ton_plus: turns_over(completed_turns, 100),
          one_forty_plus: turns_over(completed_turns, 140),
          one_eighty: turns_over(completed_turns, 180),
          split: split,
          per_dart: per_dart_averages(completed_turns),
          checkout: checkout_stats_for(player),
          best_leg: best_leg_for(player),
          best_leg_darts: best_leg_darts_for(player),
          recent_turns: completed_turns.last(5).reverse,
          previous_turn_throws: recent_current_leg_throws.reject { |throw| last_turn_throw_ids.include?(throw.id) }.first(3),
          last_completed_turn_in_current_leg: last_completed_turn
        }
      }
    end
  end

  def average_per_turn_for(player_id, completed_turns)
    total_throws = @all_throws[player_id].size
    return 0.0 if completed_turns.empty? || total_throws.zero?

    total_turns = (total_throws.to_f / 3).ceil
    (completed_turns.sum { |turn| turn_total_for(turn) }.to_f / total_turns).round(1)
  end

  def summary_player_payload(player)
    {
      id: player.id,
      name: player.display_name,
      score: score_for(player),
      avg: three_dart_average(player),
      winner: winner == player
    }
  end

  def state_player_payload(player)
    {
      id: player.id,
      name: player.display_name,
      score: score_for(player),
      avg: three_dart_average(player),
      sets_won: sets_won_by(player),
      legs_won: legs_won_by(player),
      winner: winner == player,
      last_throws: last_turn_throws_for(player).map do |throw|
        {
          segment: throw.segment,
          multiplier: throw.multiplier,
          points: throw.points
        }
      end,
      checkout: match.double_out? ? CheckoutCalculator.suggest(score_for(player)) : []
    }
  end

  def player_state(player)
    @player_states.fetch(player_key(player))
  end

  def player_key(player)
    player.is_a?(Player) ? player.id : player
  end

  def average_for(turns)
    return 0.0 if turns.empty?

    total = turns.sum { |turn| turn_total_for(turn) }
    (total.to_f / turns.size).round(1)
  end

  def turn_total_for(turn)
    @turn_totals[turn.id] ||= turn.total_score.presence || turn.throws.to_a.sum(&:points)
  end

  def turns_over(turns, threshold)
    turns.count { |turn| turn_total_for(turn) >= threshold }
  end

  def per_dart_averages(turns)
    buckets = { 1 => [], 2 => [], 3 => [] }

    turns.each do |turn|
      turn.throws.to_a.sort_by(&:created_at).each_with_index do |throw, index|
        buckets[index + 1] << throw.points if buckets.key?(index + 1)
      end
    end

    buckets.transform_values do |values|
      values.empty? ? 0.0 : (values.sum.to_f / values.size).round(1)
    end
  end

  def checkout_stats_for(player)
    player_id = player_key(player)
    chances = 0
    hits = 0
    darts_used = []

    @match_sets.flat_map(&:legs).sort_by(&:created_at).each do |leg|
      score = match.starting_score

      leg.turns.to_a.sort_by(&:created_at).each do |turn|
        next unless turn.player_id == player_id

        chances += 1 if score.between?(2, 170)
        total = turn_total_for(turn)
        new_score = score - total
        score = if new_score < 0 || new_score == 1
          score
        elsif new_score.zero?
          0
        else
          new_score
        end
      end

      next unless leg.winner_id == player_id && leg.checkout_throws.present?

      darts_used << leg.checkout_throws
      hits += 1
    end

    {
      chances: chances,
      hits: hits,
      rate: chances.zero? ? 0.0 : ((hits.to_f / chances) * 100).round(1),
      average_darts: darts_used.empty? ? 0.0 : (darts_used.sum.to_f / darts_used.size).round(1)
    }
  end

  def best_leg_for(player)
    @winning_legs[player_key(player)].min_by do |leg|
      leg.turns.count { |turn| turn.player_id == player_key(player) && turn.throws.any? }
    end
  end

  def best_leg_darts_for(player)
    leg = best_leg_for(player)
    return nil unless leg

    leg.turns.sum do |turn|
      turn.player_id == player_key(player) ? turn.throws.size : 0
    end
  end

  def winning_player_id
    return @match_sets.last&.winner_id if match.finished? && match.best_of_sets > 1

    @match_sets.last&.legs&.to_a&.max_by(&:created_at)&.winner_id
  end
end
