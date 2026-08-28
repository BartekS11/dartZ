class TournamentGenerator
  def initialize(tournament)
    @tournament = tournament
  end

  def call
    @tournament.rounds.destroy_all
    @tournament.tournament_matches.destroy_all

    case @tournament.format_type
    when "groups", "groups_playoffs" then generate_groups
    when "swiss", "swiss_playoffs" then generate_swiss_round_one
    when "playoffs" then generate_playoffs
    end

    @tournament.update!(status: "active", published_at: (@tournament.published_at || Time.current))
    TournamentProgressor.new(@tournament).call
  end

  private

  def ordered_entries
    entries = @tournament.entries.order(Arel.sql("COALESCE(seed, 999999), lower(name)"))
    @tournament.seeding_mode == "manual" ? entries.to_a : entries.shuffle
  end

  def generate_groups
    entries = ordered_entries
    groups_by_name = if @tournament.seeding_mode == "manual" && entries.any? { |entry| entry.group_name.present? }
      entries.group_by { |entry| entry.group_name.presence || "A" }.sort.to_h
    else
      group_count = @tournament.effective_group_count(entries_count: entries.size)
      groups = Array.new(group_count) { [] }
      entries.each_with_index { |entry, idx| groups[idx % group_count] << entry }
      groups.each_with_index.to_h { |group_entries, idx| [ TournamentGroupNaming.label(idx), group_entries ] }
    end

    groups_by_name.each_with_index do |(group_name, group_entries), idx|
      next if group_entries.blank?

      group_entries.each { |entry| entry.update!(group_name:) }
      round = @tournament.rounds.create!(number: idx + 1, name: "Group #{group_name}", stage_type: "groups", group_name:, status: "active")
      round_robin_pairs(group_entries).each_with_index do |(home, away), pos|
        round.tournament_matches.create!(tournament: @tournament, home_entry: home, away_entry: away, position: pos + 1, **@tournament.group_match_settings)
      end
    end
  end

  def generate_swiss_round_one
    SwissRoundGenerator.new(@tournament).call
  end

  def generate_playoffs
    entries = ordered_entries
    bracket_size = 1
    bracket_size *= 2 while bracket_size < entries.size
    seeded = entries + Array.new(bracket_size - entries.size)
    round = @tournament.rounds.create!(number: 1, name: "#{@tournament.playoff_mode == 'double_elimination' ? 'Upper' : 'Playoff'} Round 1", stage_type: "playoffs", bracket: "upper", status: "active")

    seeded.each_slice(2).with_index do |(home, away), idx|
      match = round.tournament_matches.create!(tournament: @tournament, home_entry: home, away_entry: away, position: idx + 1, **@tournament.playoff_match_settings_for_entries(entries.size, bracket: "upper"))
      if home.present? && away.nil?
        match.update!(bye: true, winner_entry: home, status: "complete", completed_at: Time.current, home_legs: match.best_of_legs)
      end
    end
  end

  def round_robin_pairs(entries)
    return [] if entries.size < 2

    list = entries.dup
    list << nil if list.size.odd?
    rounds = []
    n = list.size

    (n - 1).times do
      half = n / 2
      left = list.take(half)
      right = list.drop(half).reverse
      rounds.concat(left.zip(right).reject { |a, b| a.nil? || b.nil? })
      list = [ list.first ] + [ list.last ] + list[1...-1]
    end

    rounds.uniq
  end
end
