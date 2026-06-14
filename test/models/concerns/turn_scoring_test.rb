require "test_helper"

class TurnScoringTest < ActiveSupport::TestCase
  test "distribute_total! does nothing when there is no active incomplete turn" do
    _match, _player, _other, _leg, turn = create_match_context
    turn.update!(completed_at: Time.current)

    assert_no_difference("Throw.count") do
      turn.distribute_total!(100)
    end
  end

  test "distribute_total! records a miss and completes the turn when total is zero" do
    _match, _player, _other, leg, turn = create_match_context

    assert_difference("Throw.count", 1) do
      turn.distribute_total!(0)
    end

    throw_record = turn.reload.throws.first
    assert_equal 0, throw_record.segment
    assert_equal "miss", throw_record.multiplier
    assert turn.completed?
    refute_equal turn.id, leg.reload.current_turn.id
  end

  test "distribute_total! splits total into valid throws and updates score" do
    _match, player, _other, leg, turn = create_match_context
    leg_player = leg.leg_players.find_by!(player: player)

    assert_difference("Throw.count", 2) do
      turn.distribute_total!(100)
    end

    assert_equal 401, leg_player.reload.score
    assert_equal 100, turn.reload.throws.sum(&:points)
    assert turn.completed?
  end

  test "points_to_segment converts common scores correctly" do
    assert_equal [20, "triple"], Turn.points_to_segment(60)
    assert_equal [20, "double"], Turn.points_to_segment(40)
    assert_equal [10, "double"], Turn.points_to_segment(20)
    assert_equal [25, "double"], Turn.points_to_segment(50)
    assert_equal [25, "single"], Turn.points_to_segment(25)
  end

  private

  def create_match_context
    match = Match.create!
    player = match.players.create!(name: "Player 1")
    other  = match.players.create!(name: "Player 2")
    set = match.match_sets.create!
    leg = set.legs.create!(match: match)
    leg.start_first_turn!
    [match, player, other, leg, leg.current_turn]
  end
end
