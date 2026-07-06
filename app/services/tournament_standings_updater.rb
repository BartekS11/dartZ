class TournamentStandingsUpdater
  def initialize(tournament)
    @tournament = tournament
  end

  def call
    reset_standings!
    apply_completed_matches!
    update_buchholz! if @tournament.swiss_stage_enabled?
  end

  private

  def reset_standings!
    @tournament.entries.find_each do |entry|
      entry.update!(wins: 0, losses: 0, draws: 0, legs_for: 0, legs_against: 0, points: 0, buchholz: 0)
    end
  end

  def apply_completed_matches!
    matches = @tournament.tournament_matches.includes(:tournament_round, :home_entry, :away_entry, :winner_entry).where(status: "complete")
    matches = matches.joins(:tournament_round).where.not(tournament_rounds: { stage_type: "playoffs" }) if @tournament.combined_with_playoffs?

    matches.find_each do |match|
      if match.bye? && match.winner_entry.present?
        entry = match.winner_entry
        entry.wins += 1
        entry.points += 1
        entry.legs_for += match.home_legs
        entry.save!
        next
      end

      next unless match.home_entry && match.away_entry

      home = match.home_entry
      away = match.away_entry
      home.legs_for += match.home_legs
      home.legs_against += match.away_legs
      away.legs_for += match.away_legs
      away.legs_against += match.home_legs

      if match.winner_entry == home
        home.wins += 1
        away.losses += 1
        home.points += 1
      elsif match.winner_entry == away
        away.wins += 1
        home.losses += 1
        away.points += 1
      else
        home.draws += 1
        away.draws += 1
      end

      home.save!
      away.save!
    end
  end

  def update_buchholz!
    points_by_entry = @tournament.entries.index_by(&:id).transform_values(&:points)

    @tournament.entries.find_each do |entry|
      opp_ids = @tournament.tournament_matches.where("home_entry_id = ? OR away_entry_id = ?", entry.id, entry.id).pluck(:home_entry_id, :away_entry_id).flatten.compact - [ entry.id ]
      buchholz = opp_ids.sum { |id| points_by_entry[id].to_i }
      entry.update!(buchholz: buchholz)
    end
  end
end
