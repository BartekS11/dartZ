class ThrowsController < ApplicationController
def create
  @turn = Turn.find(params[:turn_id])

  Throw.transaction do
    @throw = @turn.throws.create!(throw_params)

    leg_player = @turn.leg.leg_players.find_by!(player: @turn.player)
    leg_player.apply_throw!(@throw.points)

    @turn.complete! if @turn.complete?
  end
end

  private

  def throw_params
   params.require(:throw).permit(:segment, :multiplier)
  end
end
