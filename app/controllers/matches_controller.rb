class MatchesController < ApplicationController
  skip_before_action :require_authentication, only: %i[index show create summary checkout]
  rescue_from ActiveRecord::RecordNotFound, with: :match_not_found

  def index
    if Current.user
      @matches = Match
        .joins(:players)
        .where(players: { user_id: Current.user.id })
        .distinct
    else
      @matches = Match.none
    end
  end

  def show
    @match = Match.find(params[:id])
    @players = @match.players
    return if @match.finished?

    current_leg  = @match.current_leg
    @turn        = current_leg&.current_turn
    @leg_player  = current_leg&.leg_players&.find_by(player: @turn&.player)
  end

  def create
    @match = Match.new(
      best_of_legs: params[:best_of_legs].to_i.clamp(1, 99),
      best_of_sets: params[:best_of_sets].to_i.clamp(1, 99)
    )

    p1_name = params[:player1_name].to_s.strip.presence || "Player 1"
    p2_name = params[:player2_name].to_s.strip.presence || "Player 2"

    @match.save!

    player1 = @match.players.create!(name: p1_name, user: Current.user)
    player2 = @match.players.create!(name: p2_name)

    @match.start_first_set!

    redirect_to match_path(@match)
  end

  def summary
    match = Match.find(params[:id])
    players_data = match.players.map do |player|
      {
        name:   player.display_name,
        score:  match.score_for(player),
        avg:    match.three_dart_average(player),
        winner: match.winner == player
      }
    end
    render json: { id: match.id, finished: match.finished?, players: players_data }
  end

  def checkout
    match  = Match.find(params[:id])
    player = match.players.find(params[:player_id])
    score  = match.score_for(player)

    suggestion = CheckoutCalculator.suggest(score)

    render json: {
      score:      score,
      suggestion: suggestion,
      possible:   suggestion.present?
    }
  end

  private

  def match_not_found
    redirect_to matches_path, alert: "Match not found"
  end
end
