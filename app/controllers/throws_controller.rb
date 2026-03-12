class ThrowsController < ApplicationController
  skip_before_action :require_authentication

  def create
    @turn  = Turn.find(params[:turn_id])
    @match = @turn.leg.match

    if params[:throw][:total].present?
      distribute_total(params[:throw][:total].to_i)
    else
      @throw = @turn.throws.create!(throw_params)
      @turn.apply_throw!(@throw)
    end

    @match.reload

    respond_to do |format|
      format.turbo_stream { render_streams }
      format.html         { redirect_to @match }
    end
  end

  def undo
    @turn  = Turn.find(params[:turn_id])
    @match = @turn.leg.match

    # Find the last turn with throws — may be @turn or the previous completed turn
    target_turn = @turn.leg.turns
                      .joins(:throws)
                      .order("turns.created_at DESC")
                      .first

    return head :no_content unless target_turn

    last_throw = target_turn.throws.order(created_at: :desc).first
    return head :no_content unless last_throw

    # Revert score
    lp = target_turn.leg.leg_players.find_by(player: target_turn.player)
    lp.update!(score: lp.score + last_throw.points)
    last_throw.destroy!

    # If target_turn was completed, destroy the current empty turn and reopen it
    if target_turn.completed?
      # @turn is the empty current turn — destroy it
      @turn.destroy! if @turn != target_turn && @turn.throws.empty?
      target_turn.update!(completed_at: nil)
    end

    @match.reload

    respond_to do |format|
      format.turbo_stream { render_streams }
      format.html         { redirect_to @match }
    end
  end

  private

  def distribute_total(total)
    remaining   = total
    throws_made = 0

    while remaining > 0 && throws_made < 3
      active_turn = @match.current_leg.current_turn
      break unless active_turn
      break if active_turn.completed?

      points              = [ remaining, 60 ].min
      segment, multiplier = points_to_segment(points)
      throw_record        = active_turn.throws.create!(segment: segment, multiplier: multiplier)
      active_turn.apply_throw!(throw_record, broadcast: false, skip_checkout_rule: true)

      remaining   -= points
      throws_made += 1
    end

    # Force complete if still open (e.g. total was less than 3 throws)
    active_turn = @match.current_leg.current_turn
    if active_turn && active_turn == @turn && !active_turn.completed?
      active_turn.complete_turn!(broadcast: false)
    end
  end

  def points_to_segment(points)
    (1..20).each { |s| return [ s, "triple" ] if s * 3 == points }
    (1..20).each { |s| return [ s, "double" ] if s * 2 == points }
    (1..20).each { |s| return [ s, "single" ] if s       == points }
    return [ 25, "double" ] if points == 50
    return [ 25, "single" ] if points == 25
    [ 1, "single" ]
  end

  def render_streams
    @match.reload
    current_turn = if @match.finished?
      nil
    else
      @match.current_leg&.current_turn
    end

    streams = @match.players.flat_map { |p|
      [
        turbo_stream.replace("score-card-#{p.id}",
          partial: "matches/score_card",
          locals:  { match: @match, player: p })
      ]
    }

    if current_turn
      streams << turbo_stream.update("current-player",
        partial: "matches/current_player",
        locals:  { match: @match, turn: current_turn })
      streams << turbo_stream.replace("dart-board",
        partial: "matches/dart_board",
        locals:  { match: @match, turn: current_turn })
    elsif @match.finished?
      streams << turbo_stream.replace("match",
        partial: "matches/game_over",
        locals:  { match: @match })
      streams << turbo_stream.remove("current-player")
      streams << turbo_stream.remove("dart-board")
    end

    render turbo_stream: streams
  end

  def throw_params
    params.require(:throw).permit(:segment, :multiplier)
  end
end
