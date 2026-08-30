# frozen_string_literal: true

require "e2e_helper"

class CheckoutScenariosFlowTest < E2EIntegrationTest
  test "checkout suggestion endpoint distinguishes possible and impossible finishes" do
    match = create_guest_match(player1: "Checkout API", player2: "Opponent", best_of_legs: 1, best_of_sets: 1, starting_score: 501, double_out: true)
    player = match.players.order(:created_at).first

    match.current_leg.leg_players.find_by!(player: player).update!(score: 170)
    get match_checkout_path(match, player)

    assert_response :success
    assert_equal 170, json_response.fetch("score")
    assert_equal true, json_response.fetch("possible")
    assert_not_empty json_response.fetch("suggestion")

    match.current_leg.leg_players.find_by!(player: player).update!(score: 169)
    get match_checkout_path(match, player)

    assert_response :success
    assert_equal 169, json_response.fetch("score")
    assert_equal false, json_response.fetch("possible")
    assert_nil json_response.fetch("suggestion")
  end

  test "one dart double-out checkout finishes leg and checkout darts can be captured" do
    match = create_guest_match(player1: "One Dart", player2: "Opponent", best_of_legs: 1, best_of_sets: 1, starting_score: 101, double_out: true)
    player = match.players.order(:created_at).first

    submit_turn_total(match.current_leg.current_turn, 61)
    assert_response :redirect
    submit_turn_total(match.reload.current_leg.current_turn, 0)
    assert_response :redirect
    assert_equal 40, match.reload.score_for(player)

    submit_checkout_double(match.current_leg.current_turn, segment: 20)
    assert_response :redirect

    finished_leg = match.reload.legs.order(:created_at).last
    assert match.finished?
    assert_equal player, finished_leg.winner

    patch leg_checkout_path(finished_leg), params: { checkout_throws: 1 }
    assert_redirected_to match_path(match)
    assert_equal 1, finished_leg.reload.checkout_throws
  end

  test "three dart checkout in one turn finishes with the final double" do
    match = create_guest_match(player1: "Three Dart", player2: "Opponent", best_of_legs: 1, best_of_sets: 1, starting_score: 101, double_out: true)
    player = match.players.order(:created_at).first
    turn = match.current_leg.current_turn

    post turn_throws_path(turn), params: { throw: { segment: 20, multiplier: "triple" } }
    assert_response :redirect
    assert_equal 41, match.reload.score_for(player)
    refute turn.reload.completed?

    post turn_throws_path(turn), params: { throw: { segment: 1, multiplier: "single" } }
    assert_response :redirect
    assert_equal 40, match.reload.score_for(player)
    refute turn.reload.completed?

    post turn_throws_path(turn), params: { throw: { segment: 20, multiplier: "double" } }
    assert_response :redirect

    finished_leg = match.reload.legs.order(:created_at).last
    assert match.finished?
    assert_equal player, finished_leg.winner
    assert_equal 3, turn.reload.throws.count
  end

  test "exact checkout on a non-double busts and passes turn to opponent" do
    match = create_guest_match(player1: "Non Double", player2: "Opponent", best_of_legs: 1, best_of_sets: 1, starting_score: 101, double_out: true)
    player = match.players.order(:created_at).first
    opponent = match.players.order(:created_at).second

    submit_turn_total(match.current_leg.current_turn, 61)
    assert_response :redirect
    submit_turn_total(match.reload.current_leg.current_turn, 0)
    assert_response :redirect
    assert_equal 40, match.reload.score_for(player)

    post turn_throws_path(match.current_leg.current_turn), params: { throw: { segment: 20, multiplier: "single" } }
    assert_response :redirect
    assert_equal 20, match.reload.score_for(player)
    refute match.current_leg.finished?

    post turn_throws_path(match.current_leg.current_turn), params: { throw: { segment: 10, multiplier: "single" } }
    assert_response :redirect
    assert_equal 10, match.reload.score_for(player)

    post turn_throws_path(match.current_leg.current_turn), params: { throw: { segment: 10, multiplier: "single" } }
    assert_response :redirect
    assert_equal 10, match.reload.score_for(player), "non-double exact finish should bust back to turn-start score"
    assert_equal opponent, match.current_leg.current_turn.player
  end

  test "leaving score one is a bust and score is restored" do
    match = create_guest_match(player1: "No Madhouse", player2: "Opponent", best_of_legs: 1, best_of_sets: 1, starting_score: 101, double_out: true)
    player = match.players.order(:created_at).first
    opponent = match.players.order(:created_at).second

    submit_turn_total(match.current_leg.current_turn, 99)
    assert_response :redirect
    submit_turn_total(match.reload.current_leg.current_turn, 0)
    assert_response :redirect
    assert_equal 2, match.reload.score_for(player)

    post turn_throws_path(match.current_leg.current_turn), params: { throw: { segment: 1, multiplier: "single" } }
    assert_response :redirect

    assert_equal 2, match.reload.score_for(player)
    assert_equal opponent, match.current_leg.current_turn.player
    refute match.current_leg.finished?
  end

  test "double-in ignores scoring until a double opens the leg" do
    match = create_guest_match(player1: "Double In", player2: "Opponent", best_of_legs: 1, best_of_sets: 1, starting_score: 101, double_in: true, double_out: true)
    player = match.players.order(:created_at).first
    turn = match.current_leg.current_turn

    post turn_throws_path(turn), params: { throw: { segment: 20, multiplier: "single" } }
    assert_response :redirect
    assert_equal 101, match.reload.score_for(player)
    refute turn.reload.completed?

    post turn_throws_path(turn), params: { throw: { segment: 20, multiplier: "double" } }
    assert_response :redirect
    assert_equal 61, match.reload.score_for(player)
    refute turn.reload.completed?
  end
end
