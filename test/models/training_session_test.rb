require "test_helper"

class TrainingSessionTest < ActiveSupport::TestCase
  test "around the clock targets include numbers and separate bulls" do
    user = create_user("training-targets@example.com")
    session = user.training_sessions.create!(mode: "around_the_clock")

    assert_equal "1", session.targets.first.fetch("label")
    assert_equal "20", session.targets[19].fetch("label")
    assert_equal "Outer Bull", session.targets[20].fetch("label")
    assert_equal "Inner Bull", session.targets[21].fetch("label")
  end

  test "doubles mode labels numeric targets as doubles" do
    user = create_user("training-doubles@example.com")
    session = user.training_sessions.create!(mode: "around_the_clock_doubles")

    assert_equal "D1", session.targets.first.fetch("label")
    assert_equal "D20", session.targets[19].fetch("label")
  end

  test "record hit advances target and keeps stats" do
    user = create_user("training-hit@example.com")
    session = user.training_sessions.create!(mode: "around_the_clock")

    session.record_hit!(misses_before_hit: 2)

    assert_equal 1, session.current_target_index
    assert_equal 3, session.total_darts
    assert_equal 2, session.misses
    assert_equal 1, session.hits
    assert_equal "1", session.target_stats.last.fetch("label")
  end

  test "record no hit keeps current target and records at least one miss" do
    user = create_user("training-no-hit@example.com")
    session = user.training_sessions.create!(mode: "around_the_clock")

    session.record_no_hit!(misses_count: 0)

    assert_equal 0, session.current_target_index
    assert_equal 1, session.total_darts
    assert_equal 1, session.misses
    assert_equal 0, session.hits
  end

  test "session completes after final target hit" do
    user = create_user("training-complete@example.com")
    session = user.training_sessions.create!(mode: "around_the_clock", current_target_index: 21)

    session.record_hit!(misses_before_hit: 0)

    assert_equal "completed", session.status
    assert_not_nil session.completed_at
  end

  test "checkout randomizer starts with possible checkout score" do
    user = create_user("training-checkout@example.com")
    session = user.training_sessions.create!(mode: "checkout_randomizer")

    assert_includes CheckoutCalculator::CHECKOUT_TABLE.keys, session.current_target_index
    assert_equal "checkout", session.current_target.fetch("kind")
    assert_not_empty session.current_target.fetch("suggestion")
  end

  test "checkout randomizer records attempt and moves to another checkout" do
    user = create_user("training-checkout-record@example.com")
    session = user.training_sessions.create!(mode: "checkout_randomizer")

    session.record_hit!(misses_before_hit: 2)

    assert_equal 3, session.total_darts
    assert_equal 2, session.misses
    assert_equal 1, session.hits
    assert_equal 1, session.target_stats.size
    assert_includes CheckoutCalculator::CHECKOUT_TABLE.keys, session.current_target_index
  end

  test "active session can be completed manually" do
    user = create_user("training-manual-complete@example.com")
    session = user.training_sessions.create!(mode: "checkout_randomizer")

    session.complete!

    assert_equal "completed", session.status
    assert_not_nil session.completed_at
  end

  test "stale active sessions are abandoned after fifteen days" do
    user = create_user("training-stale@example.com")
    session = user.training_sessions.create!(mode: "around_the_clock", started_at: 16.days.ago)

    TrainingSession.abandon_stale!

    assert_equal "abandoned", session.reload.status
    assert_not_nil session.abandoned_at
  end
end
