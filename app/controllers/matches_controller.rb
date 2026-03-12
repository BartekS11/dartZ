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
    @leg  = @match.ensure_current_leg!
    @turn = @leg.ensure_current_turn!
    @leg_player = @leg.leg_players.find_by!(player: @turn.player)
  end

  def create
    match = Match.create!

    player1_name = params[:player1_name].presence
    player2_name = params[:player2_name].presence

    if Current.user
      # Logged in — first player is the user
      match.players.create!(
        user: Current.user,
        name: player1_name || Current.user.email_address
      )
    else
      # Guest — just a name
      match.players.create!(name: player1_name || "Player 1")
    end

    match.players.create!(name: player2_name || "Player 2")

    redirect_to match
  end

  def throws
    @match  = Match.find(params[:id])
    @player = @match.players.find(params[:player_id])
    @throws = @match.all_throws_for(@player)
  end

  def summary
    match = Match.find(params[:id])
    players_data = match.players.map do |player|
      {
        name: player.display_name,
        score: match.score_for(player),
        winner: match.winner == player
      }
    end
    render json: { id: match.id, finished: match.finished?, players: players_data }
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
