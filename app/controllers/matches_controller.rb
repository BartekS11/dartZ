class MatchesController < ApplicationController
  def index
    @matches = Current.user.players.includes(:matches).flat_map(&:matches)
  end

  def show
    @match = Match.find(params[:id])
    @leg = @match.current_leg
    @turn = @leg.current_turn
  end


  def create
    player = Current.user.players.first
    match = player.matches.create!
    redirect_to match
  end
end
