require "test_helper"

class Training::ExpandedModesTest < ActiveSupport::TestCase
  setup { @user = create_user("expanded-modes-#{SecureRandom.hex(4)}@example.com") }

  test "Bob's 27 scores hits, miss penalties, and early termination" do
    session = Training::SessionStarter.call(user: @user, mode: "bobs_27")
    record(session, { hits: 2 })
    assert_equal 31, session.reload.score
    record(session, { hits: 0 })
    assert_equal 27, session.reload.score

    session.update!(score: 1)
    record(session, { hits: 0 })
    assert session.reload.completed?
    assert session.state.fetch("ended_below_zero")
  end

  test "doubles practice advances configured range and reports hit rate" do
    session = Training::SessionStarter.call(user: @user, mode: "doubles_practice", configuration: { from: 19, to: 20 })
    record(session, { hits: 2 })
    assert_equal "D20", session.reload.current_target.fetch("label")
    record(session, { hits: 1 })
    assert session.reload.completed?
    assert_equal 50.0, session.summary.fetch(:hit_rate)
  end

  test "99 dart scoring stores thirds and overall average" do
    session = Training::SessionStarter.call(user: @user, mode: "scoring_99")
    33.times { record(session, { score: 60, darts: 3 }) }

    assert session.reload.completed?
    assert_equal 1_980, session.score
    assert_equal({ "1" => 660, "2" => 660, "3" => 660 }, session.state.fetch("segment_scores"))
    assert_equal 60.0, session.session_progress.fetch(:overall_average)
  end

  test "Checkout 121 progresses and regresses after configured failures" do
    session = Training::SessionStarter.call(user: @user, mode: "checkout_121", configuration: { rounds: 4 })
    record(session, { checkout: true, darts: 3 })
    assert_equal 122, session.reload.state.fetch("checkout")
    3.times { record(session, { checkout: false, darts: 3 }) }
    assert session.reload.completed?
    assert_equal 121, session.state.fetch("checkout")
  end

  test "custom targets validate and repeat their sequence" do
    session = Training::SessionStarter.call(user: @user, mode: "custom_targets", configuration: {
      targets: %w[S20 D16 IB], darts_per_target: 3, repetitions: 2, required_hits: 2
    })
    6.times { record(session, { hits: 2 }) }

    assert session.reload.completed?
    assert_equal 6, session.training_attempts.count
    assert_raises(Training::InvalidAttempt) do
      Training::SessionStarter.call(user: @user, mode: "custom_targets", configuration: { targets: [ "D21" ] })
    end
  end

  test "attempt UUID is idempotent and finished sessions reject updates" do
    session = Training::SessionStarter.call(user: @user, mode: "doubles_practice", configuration: { from: 20, to: 20 })
    key = SecureRandom.uuid
    first = Training::AttemptRecorder.call(session: session, idempotency_key: key, result: { hits: 1 })
    replay = Training::AttemptRecorder.call(session: session.reload, idempotency_key: key, result: { hits: 3 })

    assert_equal first, replay
    assert_equal 3, session.reload.total_darts
    assert_raises(Training::InvalidAttempt) { record(session, { hits: 1 }) }
  end

  private

  def record(session, result)
    Training::AttemptRecorder.call(session: session.reload, idempotency_key: SecureRandom.uuid, result: result)
  end
end
