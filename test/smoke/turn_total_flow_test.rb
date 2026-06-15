require "test_helper"

class TurnTotalFlowTest < ActionDispatch::IntegrationTest
  test "submitting a turn total updates score and advances turn" do
    match = Match.create!(best_of_legs: 1, best_of_sets: 1)
    player1 = match.players.create!(name: "Alice")
    player2 = match.players.create!(name: "Bob")
    match.start_first_set!

    turn = match.current_leg.current_turn
    assert_equal player1, turn.player

    post turn_throws_path(turn),
         params: { throw: { total: 60 } },
         headers: { "Accept" => "text/vnd.turbo-stream.html" }

    assert_response :success

    match.reload
    assert_equal 441, match.score_for(player1)
    assert_equal player2, match.current_leg.current_turn.player
    assert_equal 60, Turn.find(turn.id).total_score
  end
end
