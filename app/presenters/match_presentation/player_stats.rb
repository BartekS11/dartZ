module MatchPresentation
  class PlayerStats
    def initialize(match, snapshot)
      @match = match
      @snapshot = snapshot
      @stats_by_player_id = {}
    end

    def stats_for(player)
      player_id = player_key(player)
      @stats_by_player_id[player_id] ||= build_stats(player_id)
    end

    private

    attr_reader :match, :snapshot

    def build_stats(player_id)
      completed_turns = snapshot.completed_turns_for(player_id)
      recent_current_leg_throws = snapshot.current_leg_throws_for(player_id).sort_by(&:created_at).reverse
      last_turn_throw_ids = last_turn_throws_for(player_id).map(&:id)
      best_leg = best_leg_for(player_id)

      {
        completed_turns: completed_turns,
        darts_thrown: snapshot.throws_for(player_id).size,
        average_per_turn: average_per_turn_for(player_id, completed_turns),
        highest_turn: completed_turns.map { |turn| snapshot.turn_total(turn) }.max.to_i,
        first_nine_avg: average_for(completed_turns.first(3)),
        ton_plus: turns_over(completed_turns, 100),
        one_forty_plus: turns_over(completed_turns, 140),
        one_eighty: turns_over(completed_turns, 180),
        split: split_for(player_id),
        per_dart: per_dart_averages(completed_turns),
        checkout: checkout_stats_for(player_id),
        best_leg: best_leg,
        best_leg_darts: best_leg_darts_for(player_id, best_leg),
        recent_turns: completed_turns.last(5).reverse,
        previous_turn_throws: recent_current_leg_throws.reject { |throw| last_turn_throw_ids.include?(throw.id) }.first(3),
        last_completed_turn_in_current_leg: snapshot.last_completed_turn_in_current_leg_for(player_id)
      }
    end

    def last_turn_throws_for(player_id)
      turn = snapshot.active_turn_for(player_id) || snapshot.last_completed_turn_in_current_leg_for(player_id)
      turn ? snapshot.ordered_throws_for(turn) : []
    end

    def average_per_turn_for(player_id, completed_turns)
      total_throws = snapshot.throws_for(player_id).size
      return 0.0 if completed_turns.empty? || total_throws.zero?

      total_turns = (total_throws.to_f / 3).ceil
      (completed_turns.sum { |turn| snapshot.turn_total(turn) }.to_f / total_turns).round(1)
    end

    def average_for(turns)
      return 0.0 if turns.empty?

      total = turns.sum { |turn| snapshot.turn_total(turn) }
      (total.to_f / turns.size).round(1)
    end

    def turns_over(turns, threshold)
      turns.count { |turn| snapshot.turn_total(turn) >= threshold }
    end

    def split_for(player_id)
      snapshot.throws_for(player_id).each_with_object(Hash.new(0)) do |throw, counts|
        counts[throw.multiplier] += 1
      end
    end

    def per_dart_averages(turns)
      buckets = { 1 => [], 2 => [], 3 => [] }

      turns.each do |turn|
        snapshot.ordered_throws_for(turn).each_with_index do |throw, index|
          buckets[index + 1] << throw.points if buckets.key?(index + 1)
        end
      end

      buckets.transform_values do |values|
        values.empty? ? 0.0 : (values.sum.to_f / values.size).round(1)
      end
    end

    def checkout_stats_for(player_id)
      chances = 0
      hits = 0
      darts_used = []

      snapshot.ordered_legs.each do |leg|
        score = match.starting_score

        snapshot.ordered_turns_for(leg).each do |turn|
          next unless turn.player_id == player_id

          chances += 1 if score.between?(2, 170)
          new_score = score - snapshot.turn_total(turn)
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

    def best_leg_for(player_id)
      snapshot.winning_legs_for(player_id).min_by do |leg|
        snapshot.ordered_turns_for(leg).count do |turn|
          turn.player_id == player_id && snapshot.ordered_throws_for(turn).any?
        end
      end
    end

    def best_leg_darts_for(player_id, leg)
      return nil unless leg

      snapshot.ordered_turns_for(leg).sum do |turn|
        turn.player_id == player_id ? snapshot.ordered_throws_for(turn).size : 0
      end
    end

    def player_key(player)
      player.is_a?(Player) ? player.id : player
    end
  end
end
