class TournamentPlayerStats
  Stat = Struct.new(
    :entry,
    :matches_played,
    :wins,
    :losses,
    :legs_for,
    :legs_against,
    :darts_thrown,
    :points_scored,
    :highest_turn,
    :ton_plus,
    :one_forty_plus,
    :one_eighty,
    keyword_init: true
  ) do
    def three_dart_average
      return 0.0 if darts_thrown.to_i.zero?

      ((points_scored.to_f / darts_thrown) * 3).round(1)
    end
  end

  def initialize(tournament)
    @tournament = tournament
  end

  def call
    stats = @tournament.entries.order(Arel.sql("COALESCE(seed, 999999), lower(name)")).index_with do |entry|
      Stat.new(
        entry: entry,
        matches_played: 0,
        wins: entry.wins,
        losses: entry.losses,
        legs_for: entry.legs_for,
        legs_against: entry.legs_against,
        darts_thrown: 0,
        points_scored: 0,
        highest_turn: 0,
        ton_plus: 0,
        one_forty_plus: 0,
        one_eighty: 0
      )
    end

    @tournament.tournament_matches.includes(:home_entry, :away_entry, linked_match: [ :players, { turns: :throws } ]).where.not(linked_match_id: nil).find_each do |tournament_match|
      add_match_stats!(stats, tournament_match, tournament_match.home_entry)
      add_match_stats!(stats, tournament_match, tournament_match.away_entry)
    end

    stats.values.sort_by { |stat| [ -stat.wins, -stat.three_dart_average, -stat.legs_for, stat.entry.name.downcase ] }
  end

  private

  def add_match_stats!(stats, tournament_match, entry)
    return unless entry && stats[entry]

    linked_match = tournament_match.linked_match
    player = linked_match.players.find { |candidate| candidate.name == entry.name }
    return unless player

    stat = stats[entry]
    stat.matches_played += 1 if tournament_match.status == "complete" || linked_match.turns.any? { |turn| turn.player_id == player.id && turn.throws.any? }

    turns = linked_match.turns.select { |turn| turn.player_id == player.id }
    turns.each do |turn|
      throws = turn.throws.to_a
      next if throws.empty?

      turn_total = turn.total_score.presence || throws.sum(&:points)
      stat.darts_thrown += throws.size
      stat.points_scored += throws.sum(&:points)
      stat.highest_turn = [ stat.highest_turn, turn_total ].max
      stat.ton_plus += 1 if turn_total >= 100
      stat.one_forty_plus += 1 if turn_total >= 140
      stat.one_eighty += 1 if turn_total == 180
    end
  end
end
