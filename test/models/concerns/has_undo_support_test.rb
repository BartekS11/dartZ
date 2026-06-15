require "test_helper"

class HasUndoSupportTest < ActiveSupport::TestCase
  test "last_turn_with_throws returns most recent turn containing throws" do
    match, player, _other, leg, turn1 = create_match_context
    create_throw(turn1, 20, :single)
    turn1.update!(completed_at: Time.current)

    leg.start_next_turn!
    turn2 = leg.current_turn
    turn2.update!(player: player)
    create_throw(turn2, 10, :single)

    assert_equal turn2, match.last_turn_with_throws
  end

  test "undo_last_throw! in single mode removes latest throw and restores score" do
    match, player, _other, leg, turn = create_match_context
    leg_player = leg.leg_players.find_by!(player: player)
    leg_player.update!(score: 441)
    create_throw(turn, 20, :triple)

    assert_difference("Throw.count", -1) do
      assert match.undo_last_throw!(mode: "single")
    end

    assert_equal 501, leg_player.reload.score
  end

  test "undo_last_throw! in total mode removes all throws from turn and restores score" do
    match, player, _other, leg, turn = create_match_context
    leg_player = leg.leg_players.find_by!(player: player)
    leg_player.update!(score: 421)
    create_throw(turn, 20, :triple)
    create_throw(turn, 20, :single)

    assert_difference("Throw.count", -2) do
      assert match.undo_last_throw!(mode: "total")
    end

    assert_equal 501, leg_player.reload.score
    assert_equal 0, turn.reload.throws.count
  end

  test "undo_last_throw! returns false when there is no turn with throws" do
    match, = create_match_context

    assert_equal false, match.undo_last_throw!(mode: "single")
  end

  test "undo_last_throw! reopens completed turn and removes empty current turn" do
    match, player, _other, leg, turn1 = create_match_context
    leg_player = leg.leg_players.find_by!(player: player)
    leg_player.update!(score: 441)
    create_throw(turn1, 20, :triple)
    turn1.update!(completed_at: Time.current)

    leg.start_next_turn!
    turn2 = leg.current_turn

    assert_difference("Turn.count", -1) do
      assert match.undo_last_throw!(mode: "total")
    end

    assert_equal turn1.id, leg.reload.current_turn.id
    assert_nil turn1.reload.completed_at
    assert_equal 501, leg_player.reload.score
    assert_not Turn.exists?(turn2.id)
  end

  private

  def create_match_context
    match = Match.create!
    player = match.players.create!(name: "Player 1")
    other  = match.players.create!(name: "Player 2")
    set = match.match_sets.create!
    leg = set.legs.create!(match: match)
    leg.start_first_turn!
    [ match, player, other, leg, leg.current_turn ]
  end

  def create_throw(turn, segment, multiplier)
    turn.throws.create!(segment: segment, multiplier: multiplier)
  end
end
