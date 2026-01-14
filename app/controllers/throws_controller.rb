class ThrowsController < ApplicationController
  def create
  turn = Turn.find(params[:turn_id])
  turn.throws.create!(throw_params)
  if turn.throws.count == 3 || turn.finished? || turn.busted?
    turn.complete!
  end

  redirect_to turn.leg.match
  end

  private

  def throw_params
   params.require(:throw).permit(:segment, :multiplier)
  end
end
