require "test_helper"

class X01GameModesTest < ActiveSupport::TestCase
  def build_match(starting_score: 301, double_in: false, double_out: true)
    match = Match.create!(best_of_legs: 1, best_of_sets: 1, starting_score:, double_in:, double_out:)
    player = match.players.create!(name: "Alpha")
    other = match.players.create!(name: "Bravo")
    match.start_first_set!
    [ match, player, other, match.current_leg.current_turn ]
  end

  def throw_dart(turn, segment, multiplier)
    dart = turn.throws.create!(segment:, multiplier:)
    turn.apply_throw!(dart, broadcast: false)
    dart
  end

  test "starts legs at selected x01 score" do
    match, player, other, = build_match(starting_score: 301)

    assert_equal 301, match.score_for(player)
    assert_equal 301, match.score_for(other)
  end

  test "straight out allows any dart to finish" do
    match, player, = build_match(starting_score: 101, double_out: false)
    match.current_leg.leg_players.find_by!(player: player).update!(score: 20)
    turn = match.current_leg.current_turn

    leg = match.current_leg
    throw_dart(turn, 20, "single")

    assert leg.reload.finished?
    assert_equal player, match.reload.winner
  end

  test "double out rejects non-double finish" do
    match, player, = build_match(starting_score: 101, double_out: true)
    match.current_leg.leg_players.find_by!(player: player).update!(score: 20)
    turn = match.current_leg.current_turn

    throw_dart(turn, 20, "single")

    assert_equal 20, match.score_for(player)
    assert_not match.current_leg.finished?
  end

  test "score one is always bust" do
    match, player, = build_match(starting_score: 101, double_out: false)
    match.current_leg.leg_players.find_by!(player: player).update!(score: 20)
    turn = match.current_leg.current_turn

    throw_dart(turn, 19, "single")

    assert_equal 20, match.score_for(player)
  end

  test "double in ignores non-doubles until first double and counts opening double" do
    match, player, = build_match(starting_score: 301, double_in: true, double_out: false)
    turn = match.current_leg.current_turn

    throw_dart(turn, 20, "single")
    assert_equal 301, match.score_for(player)
    assert match.current_leg.leg_players.find_by!(player: player).needs_double_in?

    throw_dart(turn, 20, "double")
    assert_equal 261, match.score_for(player)
    assert_not match.current_leg.leg_players.find_by!(player: player).needs_double_in?
  end
end
