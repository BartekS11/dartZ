require "test_helper"

class MatchStatePresenterTest < ActiveSupport::TestCase
  test "last_turn_total_for returns last completed turn total in current leg" do
    match = Match.create!(starting_score: 501)
    player = match.players.create!(name: "Player 1")
    other = match.players.create!(name: "Player 2")
    match.start_first_set!

    turn = match.current_leg.current_turn
    assert_equal player, turn.player
    turn.throws.create!(segment: 20, multiplier: "triple")
    turn.update!(total_score: 60, completed_at: Time.current)
    match.current_leg.turns.create!(player: other)

    presenter = MatchStatePresenter.new(match.reload)

    assert_equal 60, presenter.last_turn_total_for(player)
    assert_nil presenter.last_turn_total_for(other)
  end
end
