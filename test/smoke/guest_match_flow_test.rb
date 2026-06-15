require "test_helper"

class GuestMatchFlowTest < ActionDispatch::IntegrationTest
  test "guest can create a match from lobby" do
    get matches_path
    assert_response :success

    assert_difference("Match.count", 1) do
      post matches_path, params: {
        player1_name: "Alice",
        player2_name: "Bob",
        best_of_legs: 3,
        best_of_sets: 1
      }
    end

    match = Match.order(:created_at).last

    assert_redirected_to match_path(match)
    assert_equal 2, match.players.count
    assert_equal [ "Alice", "Bob" ], match.players.order(:created_at).pluck(:name)
    assert_not_nil match.match_identifier
    assert_not_nil match.current_leg
    assert_not_nil match.current_leg.current_turn
  end
end
