class ThrowsController < ApplicationController
  skip_before_action :require_authentication

  def create
  @turn  = Turn.find(params[:turn_id])
  @match = @turn.leg.match

  if params[:throw][:total].present?
    # Turn total mode — submit 3 dummy throws that sum to total
    total = params[:throw][:total].to_i
    distribute_total(total)
  else
    @throw = @turn.throws.create!(throw_params)
    @turn.apply_throw!(@throw)
  end

  @match.reload
  respond_to do |format|
    format.turbo_stream { render_streams }
    format.html { redirect_to @match }
  end
end

private

def distribute_total(total)
  # Split total into up to 3 throws of max 60 each
  remaining = total
  throws_made = 0

  while remaining > 0 && throws_made < 3
    points = [ remaining, 60 ].min
    # Find a valid segment/multiplier combo for these points
    segment, multiplier = points_to_segment(points)
    throw = @turn.throws.create!(segment: segment, multiplier: multiplier)
    @turn.apply_throw!(throw)
    @turn.reload
    remaining -= points
    throws_made += 1
    break if @turn.completed?
  end
end

def points_to_segment(points)
  # Try triple first, then double, then single
  (1..20).each { |s| return [ s, "triple" ] if s * 3 == points }
  (1..20).each { |s| return [ s, "double" ] if s * 2 == points }
  (1..20).each { |s| return [ s, "single" ] if s       == points }
  return [ 25, "double" ] if points == 50
  return [ 25, "single" ] if points == 25
  # fallback — store as single with closest segment
  [ 1, "single" ]
end

def render_streams
  streams  = @match.players.map { |p| turbo_stream.update("player-#{p.id}-score", html: @match.score_for(p).to_s) }
  streams += @match.players.map { |p| turbo_stream.replace("player-panel-#{p.id}", partial: "matches/player_panel", locals: { match: @match, player: p }) }
  render turbo_stream: streams
end

  # def throw_params
  #   params.require(:throw).permit(:segment, :multiplier)
  # end

  private

  def throw_params
   params.require(:throw).permit(:segment, :multiplier)
  end
end
