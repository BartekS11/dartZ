class MatchStatePresenter
  attr_reader :match

  def initialize(match)
    @match = match
    @snapshot = MatchPresentation::Snapshot.new(match)
    @player_states = {}
  end

  def players
    @snapshot.players
  end

  def current_set
    @snapshot.current_set
  end

  def current_leg
    @snapshot.current_leg
  end

  def current_turn
    @snapshot.current_turn
  end

  def current_player
    players.find { |player| player.id == current_turn&.player_id }
  end

  def winner
    @snapshot.winner
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
    player_id = ensure_player!(player)
    turn = @snapshot.last_completed_turn_in_current_leg_for(player_id)
    return nil unless turn

    turn_total(turn)
  end

  def last_throws_for(player, limit: 3)
    player_state(player)[:last_throws].first(limit)
  end

  def needs_double_in?(player)
    return false unless match.double_in? && current_leg

    current_leg.leg_players.find { |leg_player| leg_player.player_id == player_key(player) }&.needs_double_in? || false
  end

  def stats_for(player)
    ensure_player!(player)
    player_stats.stats_for(player)
  end

  def average_per_turn(player)
    stats_for(player)[:average_per_turn]
  end

  def turn_total(turn)
    @snapshot.turn_total(turn)
  end

  def leg_number_for(leg)
    @snapshot.leg_number_for(leg)
  end

  def summary_payload
    {
      id: match.public_id,
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
      id: match.public_id,
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
      current_turn_id: current_turn&.public_id,
      players: players.map { |player| state_player_payload(player) }
    }
  end

  private

  def player_state(player)
    player_id = ensure_player!(player)
    @player_states[player_id] ||= build_player_state(player_id)
  end

  def build_player_state(player_id)
    completed_turns = @snapshot.completed_turns_for(player_id)
    avg_turns = finished? ? completed_turns : @snapshot.current_leg_completed_turns_for(player_id)
    active_turn = @snapshot.active_turn_for(player_id)
    last_completed_turn = @snapshot.last_completed_turn_in_current_leg_for(player_id)
    last_turn = active_turn || last_completed_turn

    {
      score: @snapshot.score_for(player_id),
      avg: average_for(avg_turns),
      sets_won: @snapshot.sets_won_by(player_id),
      legs_won: @snapshot.legs_won_by(player_id),
      last_turn_throws: last_turn ? @snapshot.ordered_throws_for(last_turn) : [],
      last_throws: @snapshot.current_leg_throws_for(player_id).sort_by(&:created_at).reverse
    }
  end

  def player_stats
    @player_stats ||= MatchPresentation::PlayerStats.new(match, @snapshot)
  end

  def ensure_player!(player)
    player_id = player_key(player)
    return player_id if players.any? { |candidate| candidate.id == player_id }

    raise KeyError, "key not found: #{player_id.inspect}"
  end

  def player_key(player)
    player.is_a?(Player) ? player.id : player
  end

  def average_for(turns)
    return 0.0 if turns.empty?

    total = turns.sum { |turn| turn_total(turn) }
    (total.to_f / turns.size).round(1)
  end

  def summary_player_payload(player)
    {
      id: player.public_id,
      name: player.display_name,
      score: score_for(player),
      avg: three_dart_average(player),
      winner: winner == player
    }
  end

  def state_player_payload(player)
    {
      id: player.public_id,
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
end
