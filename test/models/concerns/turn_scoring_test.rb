require "test_helper"

class TurnScoringTest < ActiveSupport::TestCase
  test "distributing 161 uses an exact checkout-friendly split" do
    match = Match.create!(best_of_legs: 1, best_of_sets: 1)
    player_one = match.players.create!(name: "Alpha")
    match.players.create!(name: "Bravo")
    match.start_first_set!

    turn = match.current_leg.current_turn
    turn.update!(player: player_one) unless turn.player == player_one

    assert_difference("Throw.count", 3) do
      turn.distribute_total!(161)
    end

    assert_equal [ 60, 51, 50 ], turn.reload.throws.order(:created_at).map(&:points)
    assert_equal 340, match.reload.score_for(player_one)
  end
end
