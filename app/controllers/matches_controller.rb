class MatchesController < ApplicationController
  def index
    @matches = Match
      .joins(:players)
      .where(players: { user_id: Current.user.id })
      .distinct
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

    match.players.create!(
    user: Current.user,
    name: Current.user.email_address
    )

    match.players.create!(
     name: "Guest"
  )

    redirect_to match
  end

  def throws
    @match  = Match.find(params[:id])
    @player = @match.players.find(params[:player_id])
    @throws = @match.all_throws_for(@player)
  end
end
