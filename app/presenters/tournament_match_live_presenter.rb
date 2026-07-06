class TournamentMatchLivePresenter
  def initialize(tournament_match)
    @tournament_match = tournament_match
    @match = tournament_match.linked_match
  end

  def live?
    @tournament_match.status == "live" && @match.present? && !@match.finished?
  end

  def primary_score
    return result_score if @tournament_match.status == "complete"
    return "Bye" if @tournament_match.bye?
    return "Waiting" unless @match

    if @tournament_match.best_of_sets > 1
      "Sets #{sets_score}"
    elsif @tournament_match.best_of_legs > 1
      "Legs #{legs_score}"
    else
      x01_score
    end
  end

  def secondary_score
    return nil unless @match && !@match.finished?
    return x01_score if @tournament_match.best_of_sets > 1 || @tournament_match.best_of_legs > 1

    current_thrower
  end

  def current_thrower
    @match.current_player&.name&.then { |name| "Throw: #{name}" }
  end

  private

  def players
    @players ||= @match&.players&.order(:created_at)&.to_a || []
  end

  def x01_score
    return "Not started" if players.size < 2

    "#{@match.score_for(players[0])} - #{@match.score_for(players[1])}"
  end

  def legs_score
    return "#{@tournament_match.home_legs}-#{@tournament_match.away_legs}" if @match&.finished?
    return "0-0" if players.size < 2 || @match.current_set.blank?

    "#{@match.current_set.legs_won_by(players[0])}-#{@match.current_set.legs_won_by(players[1])}"
  end

  def sets_score
    return "#{@tournament_match.home_sets}-#{@tournament_match.away_sets}" if @match&.finished?
    return "0-0" if players.size < 2

    "#{@match.sets_won_by(players[0])}-#{@match.sets_won_by(players[1])}"
  end

  def result_score
    if @tournament_match.best_of_sets > 1
      "Sets #{@tournament_match.home_sets}-#{@tournament_match.away_sets}"
    else
      "Legs #{@tournament_match.home_legs}-#{@tournament_match.away_legs}"
    end
  end
end
