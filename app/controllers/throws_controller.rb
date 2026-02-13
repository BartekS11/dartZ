class ThrowsController < ApplicationController
  def create
    @turn = Turn.find(params[:turn_id])
    @throw = @turn.throws.create!(throw_params)

    @turn.apply_throw!(@throw)

    respond_to do |format|
      format.turbo_stream
      format.html { redirect_to @turn.leg.match }
    end
  end

  private

  def throw_params
   params.require(:throw).permit(:segment, :multiplier)
  end
end
