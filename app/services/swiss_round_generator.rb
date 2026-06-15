require "set"

class SwissRoundGenerator
  def initialize(tournament)
    @tournament = tournament
  end

  def call
    return unless @tournament.format_type == "swiss"
    return unless @tournament.can_generate_next_swiss_round?

    entries = ranked_entries
    round_number = @tournament.next_swiss_round_number
    round = @tournament.rounds.create!(
      number: round_number,
      name: "Swiss Round #{round_number}",
      stage_type: "swiss",
      status: "active"
    )

    if entries.size.odd?
      bye_entry = select_bye_entry(entries)
      entries = entries - [bye_entry]
      round.tournament_matches.create!(
        tournament: @tournament,
        home_entry: bye_entry,
        winner_entry: bye_entry,
        bye: true,
        status: "complete",
        completed_at: Time.current,
        best_of_legs: @tournament.best_of_legs,
        best_of_sets: @tournament.best_of_sets,
        home_legs: @tournament.best_of_legs
      )
    end

    pairings = build_pairings(entries)
    pairings.each_with_index do |(home, away), idx|
      round.tournament_matches.create!(
        tournament: @tournament,
        home_entry: home,
        away_entry: away,
        position: idx + 1,
        best_of_legs: @tournament.best_of_legs,
        best_of_sets: @tournament.best_of_sets
      )
    end

    round
  end

  private

  def ranked_entries
    @tournament.standings.dup
  end

  def select_bye_entry(entries)
    prior_byes = @tournament.tournament_matches.where(bye: true).pluck(:winner_entry_id).compact
    eligible = entries.reject { |entry| prior_byes.include?(entry.id) }
    pool = eligible.presence || entries
    pool.min_by { |entry| [entry.wins, entry.leg_difference, entry.points, entry.buchholz.to_f, entry.name.downcase] }
  end

  def build_pairings(entries)
    previous_opponents = opponents_map
    backtrack_pairings(entries, previous_opponents) || fallback_pairings(entries)
  end

  def backtrack_pairings(entries, previous_opponents)
    return [] if entries.empty?

    first = entries.first
    rest = entries.drop(1)
    ordered_candidates = rest.sort_by do |candidate|
      [
        previous_opponents.fetch(first.id, Set.new).include?(candidate.id) ? 1 : 0,
        (first.points - candidate.points).abs,
        (first.wins - candidate.wins).abs,
        (first.leg_difference - candidate.leg_difference).abs
      ]
    end

    ordered_candidates.each do |candidate|
      next if previous_opponents.fetch(first.id, Set.new).include?(candidate.id)

      remaining = rest - [candidate]
      tail = backtrack_pairings(remaining, previous_opponents)
      return [[first, candidate], *tail] if tail
    end

    nil
  end

  def fallback_pairings(entries)
    entries.each_slice(2).to_a
  end

  def opponents_map
    map = Hash.new { |hash, key| hash[key] = Set.new }

    @tournament.tournament_matches.where.not(home_entry_id: nil).where.not(away_entry_id: nil).find_each do |match|
      map[match.home_entry_id] << match.away_entry_id
      map[match.away_entry_id] << match.home_entry_id
    end

    map
  end
end
