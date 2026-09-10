require "test_helper"

class DartSetupStatistics::PlayerMatchStatsTest < ActiveSupport::TestCase
  test "aggregates persisted and calculated totals with existing checkout semantics" do
    match = Match.create!(starting_score: 301, best_of_legs: 3)
    player = match.players.create!(name: "Setup Owner")
    opponent = match.players.create!(name: "Opponent")
    match_set = match.match_sets.create!

    winning_leg = match_set.legs.create!(
      match:,
      winner_id: player.id,
      finished_at: Time.current,
      checkout_throws: 2
    )
    create_turn(winning_leg, player, [ [ 20, :triple ], [ 20, :double ], [ 20, :single ] ], total_score: 180)
    create_turn(winning_leg, opponent, [ [ 20, :single ] ], total_score: 20)
    create_turn(winning_leg, player, [ [ 20, :triple ], [ 20, :triple ], [ 1, :single ] ], total_score: nil)

    active_leg = match_set.legs.create!(match:)
    create_turn(active_leg, player, [ [ 5, :single ], [ 20, :single ] ], total_score: nil)
    create_turn(active_leg, player, [ [ 19, :triple ] ], total_score: nil, completed: false)

    stats = DartSetupStatistics::PlayerMatchStats.new(player.reload).aggregate

    assert_equal({
      completed_turns: 3,
      darts_thrown: 9,
      total_score: 326,
      highest_turn: 180,
      double_hits: 1,
      checkout_chances: 1,
      checkout_hits: 1
    }, stats)
  end

  test "memoizes the aggregate for one request-local collaborator" do
    match = Match.create!
    player = match.players.create!(name: "Setup Owner")
    match.players.create!(name: "Opponent")
    match.start_first_set!
    collaborator = DartSetupStatistics::PlayerMatchStats.new(player.reload)

    assert_same collaborator.aggregate, collaborator.aggregate
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
