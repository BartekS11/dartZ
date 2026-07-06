require "test_helper"

class TurnScoringTest < ActiveSupport::TestCase
  test "total entry subtracts score and advances to next player" do
    match = Match.create!(best_of_legs: 1, best_of_sets: 1, starting_score: 501)
    player_one = match.players.create!(name: "Alpha")
    player_two = match.players.create!(name: "Bravo")
    match.start_first_set!

    turn = match.current_leg.current_turn
    turn.distribute_total!(180)

    assert_equal 321, match.reload.score_for(player_one)
    assert turn.reload.completed?
    assert_equal player_two, match.current_leg.current_turn.player
  end

  test "bust total leaves score unchanged and advances turn" do
    match = Match.create!(best_of_legs: 1, best_of_sets: 1, starting_score: 501)
    player_one = match.players.create!(name: "Alpha")
    player_two = match.players.create!(name: "Bravo")
    match.start_first_set!

    turn = match.current_leg.current_turn
    turn.leg.leg_players.find_by!(player: player_one).update!(score: 40)
    turn.distribute_total!(45)

    assert_equal 40, match.reload.score_for(player_one)
    assert turn.reload.completed?
    assert_equal player_two, match.current_leg.current_turn.player
  end

  test "single throw must respect double out checkout rule" do
    match = Match.create!(best_of_legs: 1, best_of_sets: 1, starting_score: 501, double_out: true)
    player_one = match.players.create!(name: "Alpha")
    match.players.create!(name: "Bravo")
    match.start_first_set!

    turn = match.current_leg.current_turn
    turn.leg.leg_players.find_by!(player: player_one).update!(score: 20)
    throw = turn.throws.create!(segment: 20, multiplier: "single")

    turn.apply_throw!(throw)

    assert_not match.reload.finished?
    assert_equal 20, match.score_for(player_one)
    assert turn.reload.completed?
  end

  test "total entry can finish 41 without busting on intermediate score 1" do
    match = Match.create!(best_of_legs: 1, best_of_sets: 1, starting_score: 501, double_out: true)
    player_one = match.players.create!(name: "Alpha")
    match.players.create!(name: "Bravo")
    match.start_first_set!

    turn = match.current_leg.current_turn
    turn.leg.leg_players.find_by!(player: player_one).update!(score: 41)

    turn.distribute_total!(41)

    assert_equal [ 39, 2 ], turn.reload.throws.order(:created_at).map(&:points)
    assert match.reload.finished?
  end

  test "total entry can finish 135" do
    match = Match.create!(best_of_legs: 1, best_of_sets: 1, starting_score: 501, double_out: true)
    player_one = match.players.create!(name: "Alpha")
    match.players.create!(name: "Bravo")
    match.start_first_set!

    turn = match.current_leg.current_turn
    turn.leg.leg_players.find_by!(player: player_one).update!(score: 135)

    turn.distribute_total!(135)

    assert_equal [ 60, 60, 15 ], turn.reload.throws.order(:created_at).map(&:points)
    assert match.reload.finished?
  end

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
