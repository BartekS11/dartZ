class MatchStatsDashboard
  attr_reader :user, :params

  def initialize(user:, params: {})
    @user = user
    @params = params || {}
  end

  def summary
    @summary ||= build_summary
  end

  def chart_data
    @chart_data ||= build_chart_data
  end

  def opponents
    Player.where(match_id: base_player_scope.select(:match_id)).where.not(user_id: user.id).distinct.order(:name).pluck(:name)
  end

  def dart_setups
    Player.where(user: user).where.not(dart_setup_fingerprint: [ nil, "" ]).distinct.pluck(:dart_setup_fingerprint, :dart_setup_snapshot).map do |fingerprint, snapshot|
      [ setup_label(snapshot), fingerprint ]
    end
  end

  private

  def build_summary
    user_players = filtered_players.to_a
    matches = user_players.map(&:match)
    turns = Turn.where(player_id: user_players.map(&:id)).includes(:throws, leg: :leg_players).to_a
    completed_turns = turns.select(&:completed?)
    throws = turns.flat_map(&:throws)
    finished_legs = Leg.where(match_id: matches.map(&:id)).where.not(winner_id: nil)

    wins = matches.count { |match| match.finished? && match.winner == user_players.find { |player| player.match_id == match.id } }
    total_score = completed_turns.sum { |turn| turn.total_score.presence || turn.throws.sum(&:points) }
    darts = throws.size
    checkout_attempts = finished_legs.count
    checkout_hits = finished_legs.where(winner_id: user_players.map(&:id)).count

    {
      matches_played: matches.size,
      wins: wins,
      losses: matches.count(&:finished?) - wins,
      legs_won: checkout_hits,
      sets_won: MatchSet.where(match_id: matches.map(&:id), winner_id: user_players.map(&:id)).count,
      three_dart_average: darts.zero? ? 0.0 : ((total_score.to_f / darts) * 3).round(1),
      first_9_average: first_9_average(user_players),
      highest_turn: completed_turns.map { |turn| turn.total_score.presence || turn.throws.sum(&:points) }.max.to_i,
      ton_plus: completed_turns.count { |turn| turn_value(turn) >= 100 },
      ton_40_plus: completed_turns.count { |turn| turn_value(turn) >= 140 },
      max_180s: completed_turns.count { |turn| turn_value(turn) == 180 },
      checkout_attempts: checkout_attempts,
      checkout_rate: checkout_attempts.zero? ? 0.0 : ((checkout_hits.to_f / checkout_attempts) * 100).round(1),
      double_hit_share: throws.empty? ? 0.0 : ((throws.count { |throw| throw.multiplier == "double" }.to_f / throws.size) * 100).round(1),
      bust_count: completed_turns.count { |turn| suspected_bust?(turn) },
      average_darts_per_won_leg: checkout_hits.zero? ? 0.0 : (darts.to_f / checkout_hits).round(1)
    }
  end

  def build_chart_data
    user_players = filtered_players.includes(match: :match_sets).to_a
    matches_by_day = user_players.group_by { |player| player.match.created_at.to_date }

    {
      average_over_time: matches_by_day.map { |date, players| [ date.iso8601, average_for_players(players) ] }.sort_by(&:first),
      win_loss: { wins: summary[:wins], losses: summary[:losses] },
      high_turns: { "100+" => summary[:ton_plus], "140+" => summary[:ton_40_plus], "180" => summary[:max_180s] },
      checkout_rate: summary[:checkout_rate]
    }
  end

  def filtered_players
    scope = base_player_scope.includes(:dart_setup, match: [ :players, :match_sets ])
    scope = scope.where(matches: { starting_score: params[:starting_score] }) if params[:starting_score].present?
    scope = scope.where(dart_setup_fingerprint: params[:dart_setup]) if params[:dart_setup].present?
    scope = scope.where(matches: { created_at: Date.parse(params[:from]).beginning_of_day.. }) if params[:from].present?
    scope = scope.where(matches: { created_at: ..Date.parse(params[:to]).end_of_day }) if params[:to].present?
    scope = filter_opponent(scope)
    scope = filter_bot(scope)
    scope = filter_tournament(scope)
    scope.distinct
  rescue Date::Error
    scope.distinct
  end

  def base_player_scope
    Player.joins(:match).where(user: user)
  end

  def filter_opponent(scope)
    return scope if params[:opponent].blank?

    scope.where(match_id: Player.where(name: params[:opponent]).where.not(user_id: user.id).select(:match_id))
  end

  def filter_bot(scope)
    case params[:opponent_type]
    when "bot"
      scope.where(match_id: Player.where(bot: true).select(:match_id))
    when "human"
      scope.where.not(match_id: Player.where(bot: true).select(:match_id))
    else
      scope
    end
  end

  def filter_tournament(scope)
    tournament_match_ids = TournamentMatch.where.not(linked_match_id: nil).select(:linked_match_id)
    case params[:match_source]
    when "tournament"
      scope.where(match_id: tournament_match_ids)
    when "casual"
      scope.where.not(match_id: tournament_match_ids)
    else
      scope
    end
  end

  def turn_value(turn)
    turn.total_score.presence || turn.throws.sum(&:points)
  end

  def first_9_average(players)
    scores = players.sum do |player|
      player.turns.includes(:throws).order(:created_at).first(3).sum { |turn| turn_value(turn) }
    end
    darts = players.sum { |player| player.turns.includes(:throws).order(:created_at).first(3).sum { |turn| turn.throws.size } }
    darts.zero? ? 0.0 : ((scores.to_f / darts) * 3).round(1)
  end

  def average_for_players(players)
    turns = Turn.where(player_id: players.map(&:id)).includes(:throws).select(&:completed?)
    darts = turns.sum { |turn| turn.throws.size }
    total = turns.sum { |turn| turn_value(turn) }
    darts.zero? ? 0.0 : ((total.to_f / darts) * 3).round(1)
  end

  def suspected_bust?(turn)
    turn.completed? && turn.throws.any? && turn_value(turn).zero?
  end

  def setup_label(snapshot)
    return "Unknown setup" unless snapshot.is_a?(Hash)

    weight = snapshot["weight_g"].to_s.sub(/\.0$/, "")
    "#{snapshot['manufacturer_label'] || snapshot['manufacturer']} · #{weight}g"
  end
end
