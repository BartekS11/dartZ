class AdvancedMatchStats
  BOGEY_SCORES = [ 169, 168, 166, 165, 163, 162, 159 ].freeze
  SCORE_BANDS = {
    "0-39" => 0..39,
    "40-59" => 40..59,
    "60-79" => 60..79,
    "80-99" => 80..99,
    "100-119" => 100..119,
    "120-139" => 120..139,
    "140-179" => 140..179,
    "180" => 180..180
  }.freeze

  TurnSample = Data.define(
    :points,
    :dart_count,
    :detailed,
    :bust,
    :checkout_opportunity,
    :checkout,
    :checkout_route,
    :created_at,
    :leg_id
  )

  MatchSample = Data.define(:match, :player, :turns, :opponent, :won, :legs_won, :sets_won) do
    def points
      turns.sum(&:points)
    end

    def darts
      turns.sum(&:dart_count)
    end

    def average
      darts.zero? ? 0.0 : ((points.to_f / darts) * 3).round(1)
    end
  end

  attr_reader :user, :filters

  def initialize(user:, filters: {})
    @user = user
    @filters = filters.to_h.symbolize_keys
  end

  def summary
    @summary ||= {
      matches_played: samples.size,
      wins: samples.count(&:won),
      losses: samples.count { |sample| sample.match.finished? && !sample.won },
      legs_won: samples.sum(&:legs_won),
      sets_won: samples.sum(&:sets_won),
      three_dart_average: average_for(turn_samples),
      first_9_average: first_nine_average,
      highest_turn: turn_samples.map(&:points).max.to_i,
      consistency: standard_deviation(turn_samples.map(&:points)),
      best_match_average: samples.map(&:average).max.to_f,
      average_darts_per_won_leg: average_darts_per_won_leg,
      bust_count: turn_samples.count(&:bust)
    }
  end

  def trends
    @trends ||= samples.group_by { |sample| sample.match.created_at.to_date.beginning_of_week }.map do |week, period_samples|
      turns = period_samples.flat_map(&:turns)
      {
        period_from: week.iso8601,
        average: average_for(turns),
        first_9_average: first_nine_average(period_samples),
        matches: period_samples.size,
        wins: period_samples.count(&:won),
        consistency: standard_deviation(turns.map(&:points))
      }
    end.sort_by { |entry| entry[:period_from] }
  end

  def distribution
    @distribution ||= SCORE_BANDS.map do |label, range|
      { band: label, count: turn_samples.count { |turn| range.cover?(turn.points) } }
    end
  end

  def checkouts
    opportunities = turn_samples.count(&:checkout_opportunity)
    completed = turn_samples.count(&:checkout)
    successful = turn_samples.select(&:checkout)
    route_counts = successful.filter_map(&:checkout_route).tally

    {
      opportunities: opportunities,
      attempts: opportunities,
      completed: completed,
      percentage: percentage(completed, opportunities),
      highest: successful.map(&:points).max.to_i,
      average_checkout_darts: average_checkout_darts,
      routes: route_counts.sort_by { |route, count| [ -count, route ] }.map { |route, count| { route: route, count: count } },
      doubles_accuracy: nil,
      doubles_accuracy_reason: "target_intent_not_recorded",
      recorded_double_hits: detailed_throws.count(&:double?)
    }
  end

  def head_to_head
    @head_to_head ||= samples.group_by { |sample| opponent_key(sample.opponent) }.map do |_key, opponent_samples|
      opponent = opponent_samples.first.opponent
      turns = opponent_samples.flat_map(&:turns)
      {
        opponent_id: opponent&.public_id,
        opponent_name: opponent&.display_name || "Unknown",
        opponent_type: opponent_type(opponent),
        matches: opponent_samples.size,
        wins: opponent_samples.count(&:won),
        losses: opponent_samples.count { |sample| sample.match.finished? && !sample.won },
        average: average_for(turns),
        last_played_at: opponent_samples.map { |sample| sample.match.created_at }.max&.iso8601
      }
    end.sort_by { |entry| [ -entry[:matches], entry[:opponent_name].downcase ] }
  end

  def leg_performance
    @leg_performance ||= samples.flat_map do |sample|
      legs_for(sample.match).filter_map do |leg|
        turns = sample.turns.select { |turn| turn.leg_id == leg.id }
        next if turns.empty?

        {
          match_id: sample.match.public_id,
          leg_id: leg.public_id,
          played_at: leg.created_at.iso8601,
          completed: leg.finished?,
          won: leg.winner_id == sample.player.id,
          average: average_for(turns),
          darts: turns.sum(&:dart_count),
          checkout: turns.any?(&:checkout)
        }
      end
    end.sort_by { |entry| entry[:played_at] }.reverse
  end

  def set_performance
    @set_performance ||= samples.flat_map do |sample|
      sample.match.match_sets.filter_map do |match_set|
        set_legs = legs_for(sample.match).select { |leg| leg.match_set_id == match_set.id }
        leg_ids = set_legs.map(&:id)
        turns = sample.turns.select { |turn| leg_ids.include?(turn.leg_id) }
        next if turns.empty?

        {
          match_id: sample.match.public_id,
          played_at: match_set.created_at.iso8601,
          completed: match_set.finished?,
          won: match_set.winner_id == sample.player.id,
          legs_won: set_legs.count { |leg| leg.winner_id == sample.player.id },
          legs_lost: set_legs.count { |leg| leg.finished? && leg.winner_id != sample.player.id },
          average: average_for(turns)
        }
      end
    end.sort_by { |entry| entry[:played_at] }.reverse
  end

  def coverage
    detailed = turn_samples.count(&:detailed)
    total = turn_samples.size

    {
      turns: total,
      detailed_turns: detailed,
      turn_total_only: total - detailed,
      detailed_percentage: percentage(detailed, total),
      doubles_accuracy_available: false
    }
  end

  def opponents
    samples.filter_map(&:opponent).uniq { |opponent| opponent_key(opponent) }
      .sort_by { |opponent| opponent.display_name.downcase }
  end

  def dart_setups
    Player.where(user: user).where.not(dart_setup_fingerprint: [ nil, "" ])
      .distinct.pluck(:dart_setup_fingerprint, :dart_setup_snapshot).map do |fingerprint, snapshot|
        { id: fingerprint, label: setup_label(snapshot) }
      end
  end

  private

  def samples
    @samples ||= filtered_players.map { |player| build_match_sample(player) }
  end

  def filtered_players
    @filtered_players ||= begin
      scope = Player.joins(:match).where(user: user)
      scope = scope.where(matches: { created_at: filters[:from].beginning_of_day.. }) if filters[:from]
      scope = scope.where(matches: { created_at: ..filters[:to].end_of_day }) if filters[:to]
      scope = scope.where(matches: { starting_score: filters[:starting_score] }) if filters[:starting_score].present?
      scope = scope.where(matches: { double_in: cast_boolean(filters[:double_in]) }) if boolean_filter?(filters[:double_in])
      scope = scope.where(matches: { double_out: cast_boolean(filters[:double_out]) }) if boolean_filter?(filters[:double_out])
      scope = filter_opponent(scope)
      scope = filter_match_source(scope)
      scope = filter_dart_setup(scope)

      scope.includes(
        :dart_setup,
        match: [
          { players: :user },
          :match_sets,
          { all_legs: { turns: :throws } }
        ]
      ).order("matches.created_at DESC", "players.id DESC").to_a
    end
  end

  def filter_opponent(scope)
    return scope if filters[:opponent_id].blank?

    opponent = Player.find_by(public_id: filters[:opponent_id])
    return scope.none unless opponent

    opponent_scope = if opponent.user_id
      Player.where(user_id: opponent.user_id)
    else
      Player.where(name: opponent.name, bot: opponent.bot)
    end
    scope.where(match_id: opponent_scope.select(:match_id))
  end

  def filter_match_source(scope)
    linked_ids = TournamentMatch.where.not(linked_match_id: nil).select(:linked_match_id)

    case filters[:match_source]
    when "tournament" then scope.where(match_id: linked_ids)
    when "casual" then scope.where.not(match_id: linked_ids)
    else scope
    end
  end

  def filter_dart_setup(scope)
    return scope if filters[:dart_setup_id].blank?

    fingerprint = filters[:dart_setup_id]
    return scope.none unless Player.where(user: user, dart_setup_fingerprint: fingerprint).exists?

    scope.where(dart_setup_fingerprint: fingerprint)
  end

  def build_match_sample(player)
    match = player.match
    turns = legs_for(match).flat_map { |leg| samples_for_leg(match, leg, player) }
    opponent = match.players.reject { |candidate| candidate.id == player.id }.first

    MatchSample.new(
      match: match,
      player: player,
      turns: turns,
      opponent: opponent,
      won: match.finished? && final_winner_id(match) == player.id,
      legs_won: legs_for(match).count { |leg| leg.winner_id == player.id },
      sets_won: match.match_sets.count { |set| set.winner_id == player.id }
    )
  end

  def samples_for_leg(match, leg, player)
    remaining = match.starting_score
    doubled_in = !match.double_in?

    leg.turns.select { |turn| turn.player_id == player.id }.sort_by { |turn| [ turn.created_at, turn.id ] }.map do |turn|
      turn_start = remaining
      checkout_opportunity = finishable?(turn_start)
      throws = turn.throws.sort_by { |dart| [ dart.created_at, dart.id ] }
      detailed = throws.any?
      bust = false
      checkout = false
      route = nil

      if detailed
        scored_throws = []
        throws.each do |dart|
          unless doubled_in
            next unless dart.double?

            doubled_in = true
          end

          candidate = remaining - dart.points
          illegal_finish = candidate.zero? && match.double_out? && !dart.double?
          if candidate.negative? || candidate == 1 || illegal_finish
            remaining = turn_start
            bust = true
            break
          end

          scored_throws << dart
          remaining = candidate
          if remaining.zero?
            checkout = true
            route = scored_throws.map { |scored_dart| dart_label(scored_dart) }.join(" ")
            break
          end
        end
      else
        recorded = turn.total_score.to_i
        doubled_in = true if match.double_in? && !doubled_in && recorded.positive?
        candidate = remaining - recorded
        confirmed_checkout = candidate.zero? && leg.winner_id == player.id
        invalid_double_out = candidate.zero? && match.double_out? && !confirmed_checkout
        bust = recorded > 180 || candidate.negative? || candidate == 1 || invalid_double_out
        remaining = candidate unless bust
        checkout = confirmed_checkout
      end

      TurnSample.new(
        points: bust ? 0 : turn_start - remaining,
        dart_count: detailed ? throws.size : inferred_dart_count(turn, checkout: checkout),
        detailed: detailed,
        bust: bust,
        checkout_opportunity: checkout_opportunity,
        checkout: checkout,
        checkout_route: route,
        created_at: turn.created_at,
        leg_id: leg.id
      )
    end
  end

  def turn_samples
    @turn_samples ||= samples.flat_map(&:turns)
  end

  def detailed_throws
    @detailed_throws ||= filtered_players.flat_map do |player|
      legs_for(player.match).flat_map do |leg|
        leg.turns.select { |turn| turn.player_id == player.id }.flat_map(&:throws)
      end
    end
  end

  def legs_for(match)
    match.all_legs
  end

  def final_winner_id(match)
    final_set = match.match_sets.sort_by { |set| [ set.created_at, set.id ] }.last
    legs_for(match).select { |leg| leg.match_set_id == final_set&.id }
      .max_by { |leg| [ leg.created_at, leg.id ] }&.winner_id
  end

  def first_nine_average(selected_samples = samples)
    points = 0
    darts = 0

    selected_samples.each do |sample|
      sample.turns.group_by(&:leg_id).each_value do |turns|
        darts_left = 9
        turns.each do |turn|
          break if darts_left.zero?

          used = [ turn.dart_count, darts_left ].min
          next if used.zero?

          points += turn.dart_count > used ? (turn.points.to_f * used / turn.dart_count) : turn.points
          darts += used
          darts_left -= used
        end
      end
    end

    darts.zero? ? 0.0 : ((points.to_f / darts) * 3).round(1)
  end

  def average_for(turns)
    darts = turns.sum(&:dart_count)
    return 0.0 if darts.zero?

    ((turns.sum(&:points).to_f / darts) * 3).round(1)
  end

  def standard_deviation(values)
    return 0.0 if values.empty?

    mean = values.sum.to_f / values.size
    variance = values.sum { |value| (value - mean)**2 } / values.size
    Math.sqrt(variance).round(1)
  end

  def average_darts_per_won_leg
    won_leg_ids = samples.flat_map do |sample|
      legs_for(sample.match).filter_map { |leg| leg.id if leg.winner_id == sample.player.id }
    end
    return 0.0 if won_leg_ids.empty?

    darts = turn_samples.select { |turn| won_leg_ids.include?(turn.leg_id) }.sum(&:dart_count)
    (darts.to_f / won_leg_ids.size).round(1)
  end

  def average_checkout_darts
    values = filtered_players.flat_map do |player|
      legs_for(player.match).filter_map do |leg|
        leg.checkout_throws if leg.winner_id == player.id && leg.checkout_throws.present?
      end
    end
    return 0.0 if values.empty?

    (values.sum.to_f / values.size).round(1)
  end

  def inferred_dart_count(turn, checkout:)
    return 0 unless turn.completed? || turn.total_score.present?
    return 0 if turn.total_score.nil?
    return [ turn.leg.checkout_throws.to_i, 1 ].max if checkout

    3
  end

  def finishable?(score)
    score.between?(2, 170) && !BOGEY_SCORES.include?(score)
  end

  def percentage(numerator, denominator)
    denominator.zero? ? 0.0 : ((numerator.to_f / denominator) * 100).round(1)
  end

  def dart_label(dart)
    return "M" if dart.miss?
    return "DB" if dart.segment == 25 && dart.double?
    return "B" if dart.segment == 25

    prefix = { "double" => "D", "triple" => "T" }.fetch(dart.multiplier, "")
    "#{prefix}#{dart.segment}"
  end

  def opponent_key(opponent)
    opponent&.user_id ? "user:#{opponent.user_id}" : "#{opponent_type(opponent)}:#{opponent&.name.to_s.downcase}"
  end

  def setup_label(snapshot)
    return "Unknown setup" unless snapshot.is_a?(Hash)

    weight = snapshot["weight_g"].to_s.sub(/\.0$/, "")
    "#{snapshot['manufacturer_label'] || snapshot['manufacturer'].to_s.humanize} · #{weight}g"
  end

  def opponent_type(opponent)
    return "bot" if opponent&.bot?
    return "registered" if opponent&.user_id

    "guest"
  end

  def boolean_filter?(value)
    %w[true false 1 0].include?(value.to_s)
  end

  def cast_boolean(value)
    ActiveModel::Type::Boolean.new.cast(value)
  end
end
