require "test_helper"

class MatchDartCountsTest < ActiveSupport::TestCase
  setup do
    @match = Match.create!(starting_score: 501, best_of_legs: 3)
    @alice = @match.players.create!(name: "Alice")
    @bob = @match.players.create!(name: "Bob")
    @set = @match.match_sets.create!
    @leg = @set.legs.create!(match: @match)
  end

  test "empty match and new players start at zero" do
    assert_counts @alice, leg: 0, total: 0
    assert_counts @bob, leg: 0, total: 0
  end

  test "counts individual darts including misses and early busts per player" do
    create_turn(@leg, @alice, [ [ 0, :miss ], [ 20, :single ] ], completed: false)
    create_turn(@leg, @bob, [ [ 20, :triple ] ])

    assert_counts @alice, leg: 2, total: 2
    assert_counts @bob, leg: 1, total: 1
  end

  test "submitted misses and busts each count as a dart" do
    @leg.leg_players.find_by!(player: @alice).update!(score: 30)
    turn = @leg.turns.create!(player: @alice)
    ThrowSubmission.call(turn: turn, throw_attributes: { segment: 0, multiplier: :miss })
    assert_counts @alice, leg: 1, total: 1
    ThrowSubmission.call(turn: turn, throw_attributes: { segment: 20, multiplier: :triple })
    assert turn.reload.completed?
    assert_counts @alice, leg: 2, total: 2
    assert_counts @bob, leg: 0, total: 0
  end

  test "match counts persist across sets" do
    create_turn(@leg, @alice, [ [ 20, :double ] ])
    @leg.update!(finished_at: Time.current, winner_id: @alice.id)
    @set.update!(finished_at: Time.current, winner_id: @alice.id)
    @match.update!(best_of_sets: 3)
    next_set = @match.match_sets.create!
    next_leg = next_set.legs.create!(match: @match)
    create_turn(next_leg, @alice, [ [ 0, :miss ] ], total_score: 0)
    assert_counts @alice, leg: 3, total: 4
  end

  test "new legs reset only leg counts and finished matches show the last leg" do
    create_turn(@leg, @alice, [ [ 20, :single ] ])
    @leg.update!(finished_at: Time.current, winner_id: @alice.id)
    second_leg = @set.legs.create!(match: @match)
    assert_counts @alice, leg: 0, total: 1

    create_turn(second_leg, @alice, [ [ 0, :miss ], [ 20, :double ] ])
    assert_counts @alice, leg: 2, total: 3
    second_leg.update!(finished_at: Time.current, winner_id: @alice.id)
    @set.update!(finished_at: Time.current, winner_id: @alice.id)
    @match.update!(finished_at: Time.current)
    assert_counts @alice, leg: 2, total: 3
  end

  test "total visits count three even for zero, short synthetic records, and busts" do
    create_turn(@leg, @alice, [ [ 0, :miss ] ], total_score: 0)
    create_turn(@leg, @alice, [ [ 20, :single ] ], total_score: 20)
    create_turn(@leg, @alice, [], total_score: 180)
    assert_counts @alice, leg: 9, total: 9
  end

  test "checkout uses confirmed dart count and falls back to records while unconfirmed" do
    create_turn(@leg, @alice, [ [ 20, :single ] ], total_score: 20)
    create_turn(@leg, @alice, [ [ 20, :double ] ], total_score: 40)
    create_turn(@leg, @bob, [ [ 20, :single ] ], total_score: 20)
    @leg.update!(finished_at: Time.current, winner_id: @alice.id)
    assert_counts @alice, leg: 4, total: 4
    assert_counts @bob, leg: 3, total: 3
    @leg.update!(checkout_throws: 2)
    assert_counts @alice, leg: 5, total: 5
  end

  test "single and total undo reduce counters using the reopened turn's remaining records" do
    @leg.leg_players.find_by!(player: @alice).update!(score: 481)
    create_turn(@leg, @alice, [ [ 20, :single ] ], total_score: 20)
    @leg.turns.create!(player: @bob)
    assert_counts @alice, leg: 3, total: 3

    assert @match.reload.undo_last_throw!(mode: "total")
    assert_counts @alice, leg: 0, total: 0

    turn = @leg.turns.find_by!(player: @alice)
    turn.throws.create!(segment: 20, multiplier: :single)
    turn.throws.create!(segment: 0, multiplier: :miss)
    assert_counts @alice, leg: 2, total: 2
    assert @match.reload.undo_last_throw!(mode: "single")
    assert_counts @alice, leg: 1, total: 1
  end

  test "counters use the preloaded graph without further queries" do
    create_turn(@leg, @alice, [ [ 20, :single ] ], total_score: 20)
    presenter = MatchStatePresenter.new(@match.reload)
    assert_no_queries do
      assert_equal 3, presenter.darts_thrown_for(@alice)
      assert_equal 3, presenter.leg_darts_thrown_for(@alice.id)
    end
  end

  private

  def assert_counts(player, leg:, total:)
    presenter = MatchStatePresenter.new(@match.reload)
    assert_equal leg, presenter.leg_darts_thrown_for(player)
    assert_equal total, presenter.darts_thrown_for(player.id)
  end

  def create_turn(leg, player, darts, completed: true, total_score: nil)
    turn = leg.turns.create!(player: player, completed_at: completed ? Time.current : nil, total_score: total_score)
    darts.each { |segment, multiplier| turn.throws.create!(segment: segment, multiplier: multiplier) }
    turn
  end
end
