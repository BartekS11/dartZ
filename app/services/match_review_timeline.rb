class MatchReviewTimeline
  def initialize(match:)
    @match = match
  end

  def legs
    match.all_legs.includes(turns: [ :player, :throws ]).order(:created_at, :id).map do |leg|
      {
        leg: leg,
        turns: leg.turns.sort_by { |turn| [ turn.created_at, turn.id ] }.map do |turn|
          {
            player: turn.player,
            score: turn.total_score.presence || turn.throws.sum(&:points),
            dart_count: turn.throws.size
          }
        end
      }
    end
  end

  private

  attr_reader :match
end
