class ThrowSubmission
  def self.call(...)
    new(...).call
  end

  def initialize(turn:, total: nil, throw_attributes: nil, broadcast: true)
    @turn = turn
    @match = turn.leg.match
    @total = total
    @throw_attributes = throw_attributes
    @broadcast = broadcast
  end

  def call
    @match.with_lock do
      @turn.reload
      total_submission? ? apply_total! : apply_single_throw!
      @match.reload
    end

    @match
  end

  private

  def total_submission?
    @total.present?
  end

  def apply_total!
    total = @total.to_i
    darts_remaining = 3 - @turn.throws.count
    max_possible = darts_remaining * 60

    @turn.update!(total_score: total)

    if total > max_possible || total > @match.score_for(@turn.player)
      @turn.complete_turn!(broadcast: false)
    else
      @turn.distribute_total!(total)
    end
  end

  def apply_single_throw!
    throw = @turn.throws.create!(@throw_attributes)
    @turn.apply_throw!(throw, broadcast: false)
  end
end
