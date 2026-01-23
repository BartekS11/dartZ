class MatchesController < ApplicationController
  def index
    @matches = Match
      .joins(:players)
      .where(players: { user_id: Current.user.id })
      .distinct
  end

  def show
    @match = Match.find(params[:id])
    return if @match.finished?

    @leg  = @match.ensure_current_leg!
    @turn = @leg.ensure_current_turn!
    @leg_player = @leg.leg_players.find_by!(player: @turn.player)
  end

  def create
    match = Match.create!

    match.players.create!(
    user: Current.user,
    name: "You"
    )

    match.players.create!(
      name: "Guest"
  )

    redirect_to match
  end
end
