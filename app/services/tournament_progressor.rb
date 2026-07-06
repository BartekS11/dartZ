class TournamentProgressor
  def initialize(tournament)
    @tournament = tournament
  end

  def call
    update_round_statuses!
    TournamentStandingsUpdater.new(@tournament).call
    auto_advance_swiss! if @tournament.auto_advance?
    auto_generate_combined_playoffs! if @tournament.auto_advance?
    auto_advance_playoffs! if @tournament.auto_advance?
    update_round_statuses!
  end

  private

  def update_round_statuses!
    @tournament.rounds.includes(:tournament_matches).find_each do |round|
      statuses = round.tournament_matches.map(&:status)
      next if statuses.empty?

      new_status = if statuses.all? { |status| status == "complete" }
                     "complete"
      elsif statuses.any? { |status| status == "live" || status == "complete" }
                     "active"
      else
                     "pending"
      end

      round.update!(status: new_status) if round.status != new_status
    end
  end

  def auto_advance_swiss!
    return unless @tournament.swiss_stage_enabled?
    return unless @tournament.can_generate_next_swiss_round?

    SwissRoundGenerator.new(@tournament).call
  end

  def auto_advance_playoffs!
    return unless @tournament.playoff_enabled?

    PlayoffProgressor.new(@tournament).call
  end

  def auto_generate_combined_playoffs!
    return unless @tournament.combined_with_playoffs?
    return if @tournament.rounds.where(stage_type: "playoffs").exists?

    case @tournament.format_type
    when "groups", "groups_playoffs"
      group_rounds = @tournament.rounds.where(stage_type: "groups")
      return if group_rounds.empty? || group_rounds.where.not(status: "complete").exists?

      group_qualifiers = @tournament.group_names.map do |group_name|
        @tournament.standings_for_group(group_name).first(@tournament.qualifiers_per_group_value)
      end
      qualifiers = first_round_group_pairing_order(group_qualifiers)
    when "swiss_playoffs"
      swiss_rounds = @tournament.rounds.where(stage_type: "swiss")
      return if swiss_rounds.empty? || @tournament.can_generate_next_swiss_round? || swiss_rounds.where.not(status: "complete").exists?

      qualifiers = @tournament.standings.first(@tournament.playoff_qualifier_count.presence || 4)
    else
      return
    end

    PlayoffProgressor.new(@tournament).create_initial_round!(qualifiers.compact)
    update_round_statuses!
  end

  def first_round_group_pairing_order(group_qualifiers)
    groups = group_qualifiers.map { |entries| entries.compact }
    return groups.flatten if groups.size < 2

    qualifier_count = groups.map(&:size).max.to_i
    ordered = []

    qualifier_count.times do |rank_index|
      groups.each_with_index do |group_entries, group_index|
        home = group_entries[rank_index]
        away_group_index = groups.size - 1 - group_index
        away_rank_index = qualifier_count - 1 - rank_index
        away = groups[away_group_index]&.[](away_rank_index)
        next if home.blank? || away.blank?
        next if away_group_index == group_index
        next if ordered.include?(home) || ordered.include?(away)

        ordered << home << away
      end
    end

    leftovers = groups.flatten.reject { |entry| ordered.include?(entry) }
    ordered.concat(leftovers)
    ordered.presence || groups.flatten
  end
end
