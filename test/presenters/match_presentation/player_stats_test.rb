require "test_helper"

class MatchPresentation::PlayerStatsTest < ActiveSupport::TestCase
  test "returns the characterized detailed statistics and memoizes them per player" do
    match = Match.create!(starting_score: 301, best_of_legs: 3)
    alice = match.players.create!(name: "Alice")
    match.players.create!(name: "Bob")
    match_set = match.match_sets.create!

    winning_leg = match_set.legs.create!(match:, winner_id: alice.id, finished_at: Time.current, checkout_throws: 2)
    first_turn = create_turn(winning_leg, alice, [ [ 20, :triple ], [ 20, :single ], [ 20, :single ] ], total_score: 180)
    second_turn = create_turn(winning_leg, alice, [ [ 20, :triple ], [ 20, :triple ], [ 1, :single ] ], total_score: nil)

    active_leg = match_set.legs.create!(match:)
    completed_turn = create_turn(active_leg, alice, [ [ 5, :single ], [ 20, :single ] ], total_score: nil)
    create_turn(active_leg, alice, [ [ 19, :triple ] ], total_score: nil, completed: false)

    snapshot = MatchPresentation::Snapshot.new(match.reload)
    collaborator = MatchPresentation::PlayerStats.new(match, snapshot)
    stats = collaborator.stats_for(alice)

    assert_same stats, collaborator.stats_for(alice.id)
    assert_equal [ first_turn.id, second_turn.id, completed_turn.id ], stats[:completed_turns].map(&:id)
    assert_equal 9, stats[:darts_thrown]
    assert_equal 108.7, stats[:average_per_turn]
    assert_equal 180, stats[:highest_turn]
    assert_equal 108.7, stats[:first_nine_avg]
    assert_equal 2, stats[:ton_plus]
    assert_equal 1, stats[:one_forty_plus]
    assert_equal 1, stats[:one_eighty]
    assert_equal({ "single" => 5, "triple" => 4 }, stats[:split])
    assert_equal({ 1 => 41.7, 2 => 33.3, 3 => 10.5 }, stats[:per_dart])
    assert_equal({ chances: 1, hits: 1, rate: 100.0, average_darts: 2.0 }, stats[:checkout])
    assert_equal winning_leg.id, stats[:best_leg].id
    assert_equal 6, stats[:best_leg_darts]
    assert_equal [ completed_turn.id, second_turn.id, first_turn.id ], stats[:recent_turns].map(&:id)
    assert_equal [ 20, 5 ], stats[:previous_turn_throws].map(&:points)
    assert_equal completed_turn.id, stats[:last_completed_turn_in_current_leg].id
  end

  private

  def create_turn(leg, player, throws, total_score:, completed: true)
    turn = leg.turns.create!(
      player:,
      total_score:,
      completed_at: completed ? Time.current : nil
    )
    throws.each { |segment, multiplier| turn.throws.create!(segment:, multiplier:) }
    turn
  end
end
