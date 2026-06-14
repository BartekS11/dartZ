require "test_helper"

class HasThrowHistoryTest < ActiveSupport::TestCase
  test "last_throws_for returns none when there is no current leg" do
    match = Match.create!
    player = match.players.create!(name: "Player 1")
    match.players.create!(name: "Player 2")

    assert_equal [], match.last_throws_for(player).to_a
  end

  test "last_throws_for returns latest throws for player in current leg" do
    match, player, _other, leg = create_match_with_leg
    turn = leg.current_turn

    create_throw(turn, 20, :triple)
    create_throw(turn, 20, :double)
    create_throw(turn, 10, :single)

    throws = match.last_throws_for(player, limit: 2).to_a

    assert_equal 2, throws.size
    assert_equal [10, 40], throws.map(&:points)
  end

  test "all_throws_for returns throws across multiple legs" do
    match, player, _other, leg1 = create_match_with_leg
    turn1 = leg1.current_turn
    create_throw(turn1, 20, :triple)
    turn1.update!(completed_at: Time.current)

    leg2 = match.current_set.legs.create!(match: match)
    leg2.start_first_turn!
    turn2 = leg2.current_turn
    create_throw(turn2, 5, :single)

    throws = match.all_throws_for(player).to_a

    assert_equal 2, throws.size
    assert_equal [5, 60], throws.map(&:points)
  end

  test "average_per_turn calculates using groups of three throws" do
    match, player, _other, leg = create_match_with_leg
    turn = leg.current_turn

    create_throw(turn, 20, :triple)
    create_throw(turn, 20, :single)
    create_throw(turn, 10, :single)
    leg.start_next_turn!
    turn2 = leg.current_turn
    turn2.update!(player: player)
    create_throw(turn2, 5, :single)

    assert_equal 47.5, match.average_per_turn(player)
  end

  test "three_dart_average uses current leg for active matches" do
    match, player, other, leg = create_match_with_leg
    turn1 = leg.current_turn
    create_throw(turn1, 20, :triple)
    turn1.update!(total_score: 60, completed_at: Time.current)

    leg.start_next_turn!
    other_turn = leg.current_turn
    other_turn.update!(player: other, completed_at: Time.current, total_score: 45)

    leg.start_next_turn!
    turn2 = leg.current_turn
    turn2.update!(player: player)
    create_throw(turn2, 20, :double)
    turn2.update!(total_score: 40, completed_at: Time.current)

    assert_equal 50.0, match.three_dart_average(player)
  end

  test "last_turn_throws_for returns active turn throws before completed turn throws" do
    match, player, _other, leg = create_match_with_leg
    active_turn = leg.current_turn
    create_throw(active_turn, 20, :single)
    create_throw(active_turn, 5, :single)

    assert_equal [20, 5], match.last_turn_throws_for(player).map(&:points)
  end

  private

  def create_match_with_leg
    match = Match.create!
    player = match.players.create!(name: "Player 1")
    other  = match.players.create!(name: "Player 2")
    set = match.match_sets.create!
    leg = set.legs.create!(match: match)
    leg.start_first_turn!
    [match, player, other, leg]
  end

  def create_throw(turn, segment, multiplier)
    turn.throws.create!(segment: segment, multiplier: multiplier)
  end
end
