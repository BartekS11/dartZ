class MatchShareSerializer
  def initialize(match:)
    @match = match
    @presenter = MatchStatePresenter.new(match)
  end

  def as_json
    winner = presenter.winner
    {
      starting_score: match.starting_score,
      game_mode_labels: match.game_mode_labels,
      players: presenter.players.each_with_index.map do |player, index|
        {
          number: index + 1,
          winner: player == winner,
          legs_or_sets_won: match.best_of_sets > 1 ? presenter.sets_won_by(player) : presenter.legs_won_by(player),
          average: presenter.three_dart_average(player)
        }
      end
    }
  end

  private

  attr_reader :match, :presenter
end
