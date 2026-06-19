class DartSetupStats
  def initialize(user:)
    @user = user
  end

  def grouped
    return [] unless @user&.premium_access?

    players = Player
      .where(user: @user)
      .where.not(dart_setup_fingerprint: [ nil, "" ])
      .includes(:dart_setup, { match: { match_sets: { legs: { turns: :throws } } } })

    groups = players.each_with_object({}) do |player, memo|
      key = player.dart_setup_fingerprint
      memo[key] ||= empty_group(player)
      add_player_stats!(memo[key], player)
    end

    groups.values.map { |group| finalize(group) }.sort_by { |group| -group[:matches] }
  end

  private

  def empty_group(player)
    {
      fingerprint: player.dart_setup_fingerprint,
      setup: player.dart_setup_summary,
      snapshot: player.dart_setup_snapshot,
      matches: 0,
      completed_turns: 0,
      darts_thrown: 0,
      total_score: 0,
      highest_turn: 0,
      double_hits: 0,
      checkout_chances: 0,
      checkout_hits: 0
    }
  end

  def add_player_stats!(group, player)
    completed_turns = player.turns.select { |turn| turn.completed_at.present? }
    throws = player.turns.flat_map { |turn| turn.throws.to_a }
    presenter_stats = MatchStatePresenter.new(player.match).stats_for(player)
    checkout = presenter_stats[:checkout]

    group[:matches] += 1
    group[:completed_turns] += completed_turns.size
    group[:darts_thrown] += throws.size
    group[:total_score] += completed_turns.sum { |turn| turn.total_score.presence || turn.throws.to_a.sum(&:points) }
    group[:highest_turn] = [ group[:highest_turn], completed_turns.map { |turn| turn.total_score.presence || turn.throws.to_a.sum(&:points) }.max.to_i ].max
    group[:double_hits] += throws.count { |throw| throw.multiplier == "double" }
    group[:checkout_chances] += checkout[:chances].to_i
    group[:checkout_hits] += checkout[:hits].to_i
  end

  def finalize(group)
    group.merge(
      average_per_turn: group[:completed_turns].zero? ? 0.0 : (group[:total_score].to_f / group[:completed_turns]).round(1),
      double_hit_share: group[:darts_thrown].zero? ? 0.0 : ((group[:double_hits].to_f / group[:darts_thrown]) * 100).round(1),
      checkout_rate: group[:checkout_chances].zero? ? 0.0 : ((group[:checkout_hits].to_f / group[:checkout_chances]) * 100).round(1)
    )
  end
end
