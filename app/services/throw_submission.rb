class ThrowSubmission
  def self.call(...)
    new(...).call
  end

  def initialize(turn:, total: nil, throw_attributes: nil, broadcast: true, current_match_player: nil)
    @turn = turn
    @match = turn.leg.match
    @total = total
    @throw_attributes = throw_attributes
    @broadcast = broadcast
    @current_match_player = current_match_player
  end

  def call
    @match.with_lock do
      @turn.reload
      total_submission? ? apply_total! : apply_single_throw!
      @match.reload
    end

    broadcast_match_update if @broadcast

    @match
  end

  private

  def broadcast_match_update
    presenter = MatchStatePresenter.new(@match)

    @match.broadcast_replace_to(
      "match_#{@match.id}",
      target: "match-live",
      partial: "matches/live",
      locals: {
        match: @match,
        presenter: presenter,
        turn: presenter.current_turn,
        current_match_player: @current_match_player
      }
    )
  end
end
