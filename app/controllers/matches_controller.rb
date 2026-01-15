class MatchesController < ApplicationController
  def index
    @matches = Match
      .joins(:players)
      .where(players: { user_id: Current.user.id })
      .distinct
  end

  def show
    @match = Match.find(params[:id])
    @leg = @match.current_leg || @match.legs.create!(starting_score: 501)
    @turn = @leg.current_turn || @leg.turns.create!(starting_score: @leg.starting_score)
  end

  def create
    match = Match.create!

    opponent = User.find_or_create_by!(
      email_address: "opponent@test.com"
    ) { |u| u.password = "password123" }

    match.players.create!(user: Current.user)
    match.players.create!(user: opponent)

    redirect_to match
  end
end

