module DartSetupStatistics
  class PlayerMatchStats
    def initialize(player)
      @player = player
    end

    def aggregate
      @aggregate ||= begin
        completed_turns = player_turns.select { |turn| turn.completed_at.present? }
        throws = player_turns.flat_map { |turn| ordered_throws_for(turn) }
        checkout = checkout_stats

        {
          completed_turns: completed_turns.size,
          darts_thrown: throws.size,
          total_score: completed_turns.sum { |turn| turn_total(turn) },
          highest_turn: completed_turns.map { |turn| turn_total(turn) }.max.to_i,
          double_hits: throws.count { |throw| throw.multiplier == "double" },
          checkout_chances: checkout[:chances],
          checkout_hits: checkout[:hits]
        }
      end
    end

    private

    attr_reader :player

    def match
      player.match
    end

    def ordered_legs
      @ordered_legs ||= match.match_sets.to_a.flat_map(&:legs).sort_by(&:created_at)
    end

    def ordered_turns_for(leg)
      @ordered_turns_by_leg_id ||= {}
      @ordered_turns_by_leg_id[leg.id] ||= leg.turns.to_a.sort_by(&:created_at)
    end

    def ordered_throws_for(turn)
      @ordered_throws_by_turn_id ||= {}
      @ordered_throws_by_turn_id[turn.id] ||= turn.throws.to_a.sort_by(&:created_at)
    end

    def player_turns
      @player_turns ||= ordered_legs.flat_map do |leg|
        ordered_turns_for(leg).select { |turn| turn.player_id == player.id }
      end
    end

    def turn_total(turn)
      @turn_totals ||= {}
      @turn_totals[turn.id] ||= turn.total_score.presence || ordered_throws_for(turn).sum(&:points)
    end

    def checkout_stats
      chances = 0
      hits = 0

      ordered_legs.each do |leg|
        score = match.starting_score

        ordered_turns_for(leg).each do |turn|
          next unless turn.player_id == player.id

          chances += 1 if score.between?(2, 170)
          new_score = score - turn_total(turn)
          score = if new_score < 0 || new_score == 1
            score
          elsif new_score.zero?
            0
          else
            new_score
          end
        end

        hits += 1 if leg.winner_id == player.id && leg.checkout_throws.present?
      end

      { chances:, hits: }
    end
  end
end
