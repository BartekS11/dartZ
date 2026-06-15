require "test_helper"

class CheckoutCaptureFlowTest < ActionDispatch::IntegrationTest
  test "checkout darts can be recorded for a finished leg" do
    match = Match.create!(best_of_legs: 1, best_of_sets: 1)
    winner = match.players.create!(name: "Alice")
    match.players.create!(name: "Bob")
    match_set = match.match_sets.create!
    leg = match_set.legs.create!(match: match)
    leg.start_first_turn!
    leg.update!(finished_at: Time.current, winner_id: winner.id)

    patch leg_checkout_path(leg),
          params: { checkout_throws: 2 },
          headers: { "Accept" => "text/vnd.turbo-stream.html" }

    assert_response :success
    assert_equal 2, leg.reload.checkout_throws
  end
end
