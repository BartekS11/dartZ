module MatchPresentation
  class Snapshot
    attr_reader :match, :players, :current_set, :current_leg, :current_turn

    def initialize(match)
      @match = match
      load_graph!
      build_indexes!
    end

    def winner
      @players_by_id[winner_id]
    end

    def score_for(player_id)
      @scores.fetch(player_id, match.starting_score)
    end

    def sets_won_by(player_id)
      @sets_won[player_id]
    end

    def legs_won_by(player_id)
      @legs_won[player_id]
    end

    def completed_turns_for(player_id)
      @all_completed_turns[player_id]
    end

    def current_leg_completed_turns_for(player_id)
      @current_leg_completed_turns[player_id]
    end

    def throws_for(player_id)
      @all_throws[player_id]
    end

    def current_leg_throws_for(player_id)
      @current_leg_throws[player_id]
    end

    def active_turn_for(player_id)
      @active_turns[player_id]
    end

    def last_completed_turn_in_current_leg_for(player_id)
      @last_completed_turns_in_current_leg[player_id]
    end

    def winning_legs_for(player_id)
      @winning_legs[player_id]
    end

    def ordered_legs
      @ordered_legs
    end

    def ordered_turns_for(leg)
      @ordered_turns_by_leg_id[leg.id]
    end

    def ordered_throws_for(turn)
      @ordered_throws_by_turn_id[turn.id] ||= turn.throws.to_a.sort_by(&:created_at)
    end

    def turn_total(turn)
      @turn_totals[turn.id] ||= turn.total_score.presence || ordered_throws_for(turn).sum(&:points)
    end

    def leg_number_for(leg)
      @leg_position[leg.id]
    end

    private

    def load_graph!
      @players = match.players_in_display_order.includes(:user).to_a
      @players_by_id = @players.index_by(&:id)
      @match_sets = match.match_sets
        .includes(legs: [ { turns: :throws }, { leg_players: :player } ])
        .order(:created_at)
        .to_a
      @ordered_legs = @match_sets.flat_map(&:legs).sort_by(&:created_at)
      @ordered_turns_by_leg_id = @ordered_legs.to_h do |leg|
        [ leg.id, leg.turns.to_a.sort_by(&:created_at) ]
      end
      @ordered_throws_by_turn_id = {}
      @ordered_turns_by_leg_id.each_value do |turns|
        turns.each do |turn|
          @ordered_throws_by_turn_id[turn.id] = turn.throws.to_a.sort_by(&:created_at)
        end
      end

      @current_set = @match_sets.reverse_each.find { |match_set| match_set.finished_at.nil? }
      @current_leg = if current_set
        current_set.legs.to_a.sort_by(&:created_at).reverse_each.find { |leg| leg.finished_at.nil? }
      end
      @current_turn = current_leg && ordered_turns_for(current_leg).max_by(&:created_at)
    end

    def build_indexes!
      @turn_totals = {}
      @all_completed_turns = grouped_collection
      @current_leg_completed_turns = grouped_collection
      @all_throws = grouped_collection
      @current_leg_throws = grouped_collection
      @winning_legs = grouped_collection
      @leg_position = {}
      @sets_won = Hash.new(0)
      @legs_won = Hash.new(0)
      @scores = Hash.new(match.starting_score)
      @active_turns = {}
      @last_completed_turns_in_current_leg = {}

      @match_sets.each do |match_set|
        @sets_won[match_set.winner_id] += 1 if match_set.winner_id
      end

      display_set = current_set || @match_sets.last
      ordered_legs.each_with_index do |leg, index|
        index_leg!(leg, index, display_set)
      end
    end

    def index_leg!(leg, index, display_set)
      @leg_position[leg.id] = index + 1
      @winning_legs[leg.winner_id] << leg if leg.winner_id
      @legs_won[leg.winner_id] += 1 if display_set && leg.match_set_id == display_set.id && leg.winner_id

      if current_leg && leg.id == current_leg.id
        leg.leg_players.each do |leg_player|
          @scores[leg_player.player_id] = leg_player.score || match.starting_score
        end
      end

      ordered_turns_for(leg).each do |turn|
        index_turn!(leg, turn)
      end
    end

    def index_turn!(leg, turn)
      throws = ordered_throws_for(turn)
      @all_throws[turn.player_id].concat(throws)

      if current_leg && leg.id == current_leg.id
        @current_leg_throws[turn.player_id].concat(throws)
        if turn.completed_at.present?
          @current_leg_completed_turns[turn.player_id] << turn
          @last_completed_turns_in_current_leg[turn.player_id] = turn
        elsif throws.any?
          @active_turns[turn.player_id] = turn
        end
      end

      return if turn.completed_at.blank?

      @all_completed_turns[turn.player_id] << turn
      @turn_totals[turn.id] = turn.total_score.presence || throws.sum(&:points)
    end

    def winner_id
      return @match_sets.last&.winner_id if match.finished? && match.best_of_sets > 1

      @match_sets.last&.legs&.to_a&.max_by(&:created_at)&.winner_id
    end

    def grouped_collection
      Hash.new { |hash, key| hash[key] = [] }
    end
  end
end
