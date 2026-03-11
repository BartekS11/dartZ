require "test_helper"

# ─────────────────────────────────────────────────────────────────────────────
# Plain Ruby stub helpers — no Minitest::Mock, no DB
# ─────────────────────────────────────────────────────────────────────────────

module Stubs
  def self.throw(points:, double: false)
    obj = Object.new
    obj.define_singleton_method(:points)  { points }
    obj.define_singleton_method(:double?) { double }
    obj
  end

  def self.leg_player(score:)
    score_val = score
    updates   = []

    obj = Object.new
    obj.define_singleton_method(:score)       { score_val }
    obj.define_singleton_method(:update!)     { |attrs| score_val = attrs[:score]; updates << attrs }
    obj.define_singleton_method(:last_update) { updates.last }
    obj
  end

  def self.leg
    obj = Object.new
    obj.define_singleton_method(:finish!) { @finished = true }
    obj.define_singleton_method(:finished?) { !!@finished }
    obj
  end

  def self.turn(score:, throw_count: 0, leg: nil)
    lp      = Stubs.leg_player(score: score)
    leg_obj = leg || Stubs.leg
    count   = throw_count

    obj = Object.new
    obj.extend(ScoringRules)

    # MAX_THROWS is defined in `included` which doesn't run on extend
    obj.define_singleton_method(:max_throws) { 3 }

    obj.define_singleton_method(:leg_player)    { lp }
    obj.define_singleton_method(:leg)           { leg_obj }
    obj.define_singleton_method(:throws) do
      inner = Object.new
      inner.define_singleton_method(:count) { count }
      inner
    end
    obj.define_singleton_method(:complete_turn!) { @completed = true }
    obj.define_singleton_method(:completed?)     { !!@completed }
    obj.define_singleton_method(:leg_player_stub) { lp }
    obj.define_singleton_method(:leg_stub)        { leg_obj }

    obj
  end
end

# ─────────────────────────────────────────────────────────────────────────────
# ScoringRules tests
# ─────────────────────────────────────────────────────────────────────────────

class ScoringRulesTest < ActiveSupport::TestCase
  # ── Score subtraction ───────────────────────────────────────────────────────

  test "single 20 subtracts 20 from score" do
    turn  = Stubs.turn(score: 501, throw_count: 0)
    throw = Stubs.throw(points: 20)

    turn.apply_throw!(throw)

    assert_equal 481, turn.leg_player_stub.score
  end

  test "double 20 subtracts 40 from score" do
    turn  = Stubs.turn(score: 501, throw_count: 0)
    throw = Stubs.throw(points: 40)

    turn.apply_throw!(throw)

    assert_equal 461, turn.leg_player_stub.score
  end

  test "triple 20 subtracts 60 from score" do
    turn  = Stubs.turn(score: 501, throw_count: 0)
    throw = Stubs.throw(points: 60)

    turn.apply_throw!(throw)

    assert_equal 441, turn.leg_player_stub.score
  end

  # ── Bust ────────────────────────────────────────────────────────────────────

  test "bust resets score when throw would go negative" do
    turn  = Stubs.turn(score: 10, throw_count: 0)
    throw = Stubs.throw(points: 20)

    turn.apply_throw!(throw)

    assert_equal 10, turn.leg_player_stub.score
  end

  test "bust resets score when new score would be 1" do
    turn  = Stubs.turn(score: 3, throw_count: 0)
    throw = Stubs.throw(points: 2)

    turn.apply_throw!(throw)

    assert_equal 3, turn.leg_player_stub.score
  end

  test "bust completes the turn" do
    turn  = Stubs.turn(score: 10, throw_count: 0)
    throw = Stubs.throw(points: 20)

    turn.apply_throw!(throw)

    assert turn.completed?, "Turn should complete after a bust"
  end

  # ── Turn completion ─────────────────────────────────────────────────────────

  test "turn completes after 3rd throw" do
    turn  = Stubs.turn(score: 501, throw_count: 3) # count after throw is applied
    throw = Stubs.throw(points: 20)

    turn.apply_throw!(throw)

    assert turn.completed?
  end

  test "turn does not complete after 2nd throw" do
    turn  = Stubs.turn(score: 501, throw_count: 2)
    throw = Stubs.throw(points: 20)

    turn.apply_throw!(throw)

    refute turn.completed?
  end

  test "turn does not complete after 1st throw" do
    turn  = Stubs.turn(score: 501, throw_count: 1)
    throw = Stubs.throw(points: 20)

    turn.apply_throw!(throw)

    refute turn.completed?
  end

  # ── Checkout ────────────────────────────────────────────────────────────────

  test "finishing on a double calls leg.finish!" do
    leg   = Stubs.leg
    turn  = Stubs.turn(score: 40, throw_count: 0, leg: leg)
    throw = Stubs.throw(points: 40, double: true)

    turn.apply_throw!(throw)

    assert leg.finished?, "leg.finish! should be called on double checkout"
    assert turn.completed?
  end

  test "finishing on a non-double busts and does not finish leg" do
    leg   = Stubs.leg
    turn  = Stubs.turn(score: 40, throw_count: 0, leg: leg)
    throw = Stubs.throw(points: 40, double: false)

    turn.apply_throw!(throw)

    refute leg.finished?, "leg should not finish on non-double"
    assert_equal 40, turn.leg_player_stub.score, "score should reset on bust"
  end

  test "score is set to 0 on valid double checkout" do
    turn  = Stubs.turn(score: 40, throw_count: 0, leg: Stubs.leg)
    throw = Stubs.throw(points: 40, double: true)

    turn.apply_throw!(throw)

    assert_equal 0, turn.leg_player_stub.score
  end
end

# ─────────────────────────────────────────────────────────────────────────────
# LegPlayer tests — uses LegPlayer.new (in-memory, no DB save)
# ─────────────────────────────────────────────────────────────────────────────

class LegPlayerTest < ActiveSupport::TestCase
  test "score cannot go below zero" do
    lp = LegPlayer.new(score: 10)
    assert_raises(ActiveRecord::RecordInvalid) { lp.apply_throw!(20) }
  end

  test "score cannot be set to 1" do
    lp = LegPlayer.new(score: 3)
    assert_raises(ActiveRecord::RecordInvalid) { lp.apply_throw!(2) }
  end

  test "finished? is true when score is 0 and throw is double" do
    lp    = LegPlayer.new(score: 0)
    throw = Stubs.throw(points: 0, double: true)

    assert lp.finished?(throw)
  end

  test "finished? is false when score is 0 but throw is not double" do
    lp    = LegPlayer.new(score: 0)
    throw = Stubs.throw(points: 0, double: false)

    refute lp.finished?(throw)
  end

  test "finished? is false when score is not 0" do
    lp    = LegPlayer.new(score: 100)
    throw = Stubs.throw(points: 40, double: true)

    refute lp.finished?(throw)
  end
end
