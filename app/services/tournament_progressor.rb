class TournamentProgressor
  def initialize(tournament)
    @tournament = tournament
  end

  def call
    update_round_statuses!
    TournamentStandingsUpdater.new(@tournament).call
    auto_advance_swiss! if @tournament.auto_advance?
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
    return unless @tournament.format_type == "swiss"
    return unless @tournament.can_generate_next_swiss_round?

    SwissRoundGenerator.new(@tournament).call
  end

  def auto_advance_playoffs!
    return unless @tournament.format_type == "playoffs"

    PlayoffProgressor.new(@tournament).call
  end
end
