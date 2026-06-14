require "test_helper"

class MatchLifecycleTest < ActiveSupport::TestCase
  test "sets_needed_to_win calculates correctly" do
    match = Match.new(best_of_sets: 5)

    assert_equal 3, match.sets_needed_to_win
    assert_equal 1, Match.new(best_of_sets: 1).sets_needed_to_win
    assert_equal 2, Match.new(best_of_sets: 4).sets_needed_to_win
  end

  test "legs_needed_to_win calculates correctly" do
    assert_equal 2, Match.new(best_of_legs: 3).legs_needed_to_win
    assert_equal 1, Match.new(best_of_legs: 1).legs_needed_to_win
    assert_equal 3, Match.new(best_of_legs: 5).legs_needed_to_win
  end

  test "sets_won_by counts finished sets for player" do
    match = create_match_with_players(best_of_sets: 5)
    player = match.players.first
    other  = match.players.second

    match.match_sets.create!(winner_id: player.id, finished_at: Time.current)
    match.match_sets.create!(winner_id: player.id, finished_at: Time.current)
    match.match_sets.create!(winner_id: other.id, finished_at: Time.current)

    assert_equal 2, match.sets_won_by(player)
    assert_equal 1, match.sets_won_by(other)
  end

  test "on_set_finished! finishes match when winner meets threshold" do
    match = create_match_with_players(best_of_sets: 3)
    winner = match.players.first
    called_with = nil

    match.define_singleton_method(:sets_won_by) { |_player| 2 }
    match.define_singleton_method(:finish!) { |player| called_with = player }

    match.on_set_finished!(winner)

    assert_equal winner, called_with
  end

  test "on_set_finished! starts next set when winner has not met threshold" do
    match = create_match_with_players(best_of_sets: 5)
    winner = match.players.first
    started = false

    match.define_singleton_method(:sets_won_by) { |_player| 2 }
    match.define_singleton_method(:start_next_set!) { started = true }

    match.on_set_finished!(winner)

    assert started
  end

  test "start_first_set! creates set, leg, and first turn" do
    match = create_match_with_players

    assert_difference("MatchSet.count", 1) do
      assert_difference("Leg.count", 1) do
        assert_difference("Turn.count", 1) do
          set = match.start_first_set!
          assert_instance_of MatchSet, set
          assert_equal match, set.match
          assert_not_nil set.current_leg
          assert_not_nil set.current_leg.current_turn
        end
      end
    end
  end

  test "start_next_set! creates a new set after first one" do
    match = create_match_with_players
    first = match.start_first_set!

    assert_difference("MatchSet.count", 1) do
      second = match.start_next_set!
      refute_equal first.id, second.id
      assert_equal match, second.match
    end
  end

  test "finish! sets finished_at" do
    match = create_match_with_players
    winner = match.players.first

    assert_nil match.finished_at

    match.finish!(winner)

    assert_not_nil match.reload.finished_at
    assert match.finished?
  end

  test "current_set returns latest unfinished set" do
    match = create_match_with_players
    finished_set = match.match_sets.create!(finished_at: Time.current)
    current_set  = match.match_sets.create!

    assert_equal current_set, match.current_set
    refute_equal finished_set, match.current_set
  end

  private

  def create_match_with_players(best_of_sets: 3, best_of_legs: 3)
    match = Match.create!(best_of_sets: best_of_sets, best_of_legs: best_of_legs)
    match.players.create!(name: "Player 1")
    match.players.create!(name: "Player 2")
    match
  end
end
