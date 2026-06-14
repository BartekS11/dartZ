require "test_helper"

class LegFlowTest < ActiveSupport::TestCase
  test "current_turn returns most recently created turn" do
    match, leg, player1, player2 = create_leg_context
    first_turn = leg.current_turn

    first_turn.update!(completed_at: Time.current)
    leg.advance_turn!

    assert_equal player2, leg.current_turn.player
    refute_equal first_turn.id, leg.current_turn.id
  end

  test "ensure_turn! returns current turn when it is incomplete" do
    _match, leg, = create_leg_context
    current_turn = leg.current_turn

    assert_equal current_turn, leg.ensure_turn!
  end

  test "ensure_turn! advances when current turn is completed" do
    _match, leg, _player1, player2 = create_leg_context
    current_turn = leg.current_turn
    current_turn.update!(completed_at: Time.current)

    next_turn = leg.ensure_turn!

    assert_equal player2, next_turn.player
    assert_not_nil next_turn.id
    refute_equal current_turn.id, next_turn.id
  end

  test "advance_turn! rotates to next player" do
    _match, leg, _player1, player2 = create_leg_context
    current_turn = leg.current_turn
    current_turn.update!(completed_at: Time.current)

    next_turn = leg.advance_turn!

    assert_equal player2, next_turn.player
  end

  test "finish! updates leg from winning leg_player and notifies match_set winner" do
    match, leg, player1, = create_leg_context
    called_with = nil
    leg.leg_players.find_by!(player: player1).update!(score: 0)

    leg.match_set.define_singleton_method(:on_leg_finished!) { |winner| called_with = winner }

    leg.finish!

    assert_not_nil leg.reload.finished_at
    assert_equal player1.id, leg.winner_id
    assert_equal player1, called_with
  end

  private

  def create_leg_context
    match = Match.create!(best_of_sets: 1, best_of_legs: 3)
    player1 = match.players.create!(name: "Player 1")
    player2 = match.players.create!(name: "Player 2")
    match_set = match.match_sets.create!
    leg = match_set.legs.create!(match: match)
    leg.start_first_turn!
    [match, leg, player1, player2]
  end
end
