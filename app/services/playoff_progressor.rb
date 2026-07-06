class PlayoffProgressor
  def initialize(tournament)
    @tournament = tournament
  end

  def call
    return unless @tournament.playoff_enabled?

    if @tournament.playoff_mode == "single_elimination"
      progress_single_elimination
    else
      progress_double_elimination
    end
  end

  def create_initial_round!(entries)
    return if @tournament.rounds.where(stage_type: "playoffs").exists?

    entries = entries.compact
    return if entries.size < 2

    bracket_size = 1
    bracket_size *= 2 while bracket_size < entries.size
    seeded = entries + Array.new(bracket_size - entries.size)
    round = @tournament.rounds.create!(number: next_round_number, name: "#{@tournament.playoff_mode == 'double_elimination' ? 'Upper' : 'Playoff'} Round 1", stage_type: "playoffs", bracket: "upper", status: "active")

    seeded.each_slice(2).with_index do |(home, away), idx|
      match = round.tournament_matches.create!(tournament: @tournament, home_entry: home, away_entry: away, bracket: "upper", position: idx + 1, **@tournament.playoff_match_settings_for_entries(entries.size, bracket: "upper"))
      if home.present? && away.nil?
        match.update!(bye: true, winner_entry: home, status: "complete", completed_at: Time.current, home_legs: match.best_of_legs)
      end
    end

    round
  end

  private

  def progress_single_elimination
    latest_upper = upper_rounds.last
    return unless latest_upper&.status == "complete"

    winners = latest_upper.tournament_matches.order(:position).map(&:winner_entry).compact
    create_bronze_round_from!(latest_upper) if should_create_bronze_round?(latest_upper, winners)

    if winners.one?
      if upper_rounds.one?
        @tournament.update!(status: "complete")
      else
        finalize_single_elimination_if_ready!
      end
      return
    end

    if champion_present?
      finalize_single_elimination_if_ready!
      return
    end
    next_number = latest_upper.number + 1
    next_bracket = winners.size == 2 ? "final" : "upper"
    return if @tournament.rounds.where(stage_type: "playoffs", number: next_number, bracket: next_bracket).exists?
    return if next_bracket == "final" && final_round.present?

    create_round_from_entries!(
      name: next_bracket == "final" ? "Grand Final" : "Playoff Round #{next_number}",
      number: next_number,
      bracket: next_bracket,
      entries: winners
    )
  end

  def progress_double_elimination
    progress_upper_bracket!
    progress_lower_bracket!
    progress_final!
    finish_if_complete!
  end

  def progress_upper_bracket!
    latest_upper = upper_rounds.last
    return unless latest_upper&.status == "complete"

    winners = latest_upper.tournament_matches.order(:position).map(&:winner_entry).compact
    return if winners.size <= 1
    return if upper_rounds.exists?(number: latest_upper.number + 1)

    create_round_from_entries!(
      name: "Upper Round #{latest_upper.number + 1}",
      number: latest_upper.number + 1,
      bracket: "upper",
      entries: winners
    )
  end

  def progress_lower_bracket!
    completed_upper_rounds.each do |upper_round|
      next if lower_round_for_upper(upper_round.number).present?

      lower_entries = if upper_round.number == 1
                        upper_round.tournament_matches.order(:position).map { |match| loser_for(match) }.compact
      else
                        previous_lower = lower_rounds.where(number: upper_round.number - 1).first
                        next unless previous_lower&.status == "complete"

                        previous_lower.tournament_matches.order(:position).map(&:winner_entry).compact +
                          upper_round.tournament_matches.order(:position).map { |match| loser_for(match) }.compact
      end

      next if lower_entries.empty?

      create_round_from_entries!(
        name: "Lower Round #{upper_round.number}",
        number: upper_round.number,
        bracket: "lower",
        entries: lower_entries
      )
    end
  end

  def progress_final!
    return if final_round.present?

    upper_champion = upper_rounds.where(status: "complete").order(:number).last&.tournament_matches&.map(&:winner_entry)&.compact&.yield_self { |w| w.one? ? w.first : nil }
    lower_champion = lower_rounds.where(status: "complete").order(:number).last&.tournament_matches&.map(&:winner_entry)&.compact&.yield_self { |w| w.one? ? w.first : nil }
    return unless upper_champion && lower_champion

    round = @tournament.rounds.create!(number: next_round_number, name: "Grand Final", stage_type: "playoffs", bracket: "final", status: "active")
    round.tournament_matches.create!(
      tournament: @tournament,
      home_entry: upper_champion,
      away_entry: lower_champion,
      position: 1,
      **@tournament.playoff_match_settings_for_entries(2, bracket: "final")
    )
  end

  def finish_if_complete!
    return unless final_round&.status == "complete"

    @tournament.update!(status: "complete")
  end

  def create_round_from_entries!(name:, number:, bracket:, entries:)
    round = @tournament.rounds.create!(number:, name:, stage_type: "playoffs", bracket:, status: "active")
    normalized = entries.dup
    normalized << nil if normalized.size.odd?

    normalized.each_slice(2).with_index do |(home, away), idx|
      match = round.tournament_matches.create!(
        tournament: @tournament,
        home_entry: home,
        away_entry: away,
        bracket:,
        position: idx + 1,
        **@tournament.playoff_match_settings_for_entries(entries.size, bracket: bracket)
      )

      if home.present? && away.nil?
        match.update!(bye: true, winner_entry: home, status: "complete", completed_at: Time.current, home_legs: match.best_of_legs)
      end
    end

    round
  end

  def loser_for(match)
    return nil unless match.home_entry && match.away_entry && match.winner_entry

    match.winner_entry == match.home_entry ? match.away_entry : match.home_entry
  end

  def upper_rounds
    @tournament.rounds.where(stage_type: "playoffs", bracket: "upper").order(:number)
  end

  def lower_rounds
    @tournament.rounds.where(stage_type: "playoffs", bracket: "lower").order(:number)
  end

  def final_round
    @tournament.rounds.find_by(stage_type: "playoffs", bracket: "final")
  end

  def completed_upper_rounds
    upper_rounds.where(status: "complete")
  end

  def lower_round_for_upper(number)
    lower_rounds.find_by(number: number)
  end

  def champion_present?
    final_round&.status == "complete"
  end

  def bronze_round
    @tournament.rounds.find_by(stage_type: "playoffs", bracket: "bronze")
  end

  def should_create_bronze_round?(round, winners)
    @tournament.bronze_match? && bronze_round.blank? && winners.size == 2 && round.tournament_matches.size == 2
  end

  def create_bronze_round_from!(round)
    losers = round.tournament_matches.order(:position).map { |match| loser_for(match) }.compact
    return if losers.size < 2

    create_round_from_entries!(
      name: "Bronze Match",
      number: next_round_number,
      bracket: "bronze",
      entries: losers.first(2)
    )
  end

  def finalize_single_elimination_if_ready!
    return unless final_round&.status == "complete"
    return if @tournament.bronze_match? && bronze_round&.status != "complete"

    @tournament.update!(status: "complete")
  end

  def next_round_number
    @tournament.rounds.maximum(:number).to_i + 1
  end
end
