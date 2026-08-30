# frozen_string_literal: true

require "e2e_helper"

class TrainingSessionsFlowTest < E2EIntegrationTest
  test "free user is redirected to billing when opening training center" do
    user = create_user(unique_email("training-free"))
    login_as(user)

    get training_sessions_path

    assert_redirected_to billing_path
    assert_equal I18n.t("flashes.premium_required"), flash[:alert]
  end

  test "premium user starts around the clock and records hit and no-hit attempts" do
    user = premium_user("training-around-clock")
    login_as(user)

    get training_sessions_path
    assert_response :success

    assert_difference("TrainingSession.count", 1) do
      post training_sessions_path, params: { training_session: { mode: "around_the_clock" } }
    end

    training_session = TrainingSession.order(:created_at).last
    assert_redirected_to training_session_path(training_session)
    assert_equal user, training_session.user
    assert_equal "around_the_clock", training_session.mode
    assert_equal "active", training_session.status
    assert_equal "1", training_session.current_target.fetch("label")

    patch record_training_session_path(training_session), params: { result: "hit", misses: 2 }
    assert_redirected_to training_session_path(training_session)

    training_session.reload
    assert_equal 1, training_session.current_target_index
    assert_equal "2", training_session.current_target.fetch("label")
    assert_equal 3, training_session.total_darts
    assert_equal 2, training_session.misses
    assert_equal 1, training_session.hits
    assert_equal({ "target" => "1", "label" => "1", "hit" => true, "misses" => 2, "darts" => 3 }, training_session.target_stats.last.except("recorded_at"))

    patch record_training_session_path(training_session), params: { result: "no_hit", misses: 0 }
    assert_redirected_to training_session_path(training_session)

    training_session.reload
    assert_equal 1, training_session.current_target_index, "no-hit should keep the current target"
    assert_equal 4, training_session.total_darts
    assert_equal 3, training_session.misses
    assert_equal 1, training_session.hits
    assert_equal false, training_session.target_stats.last.fetch("hit")
    assert_equal 1, training_session.target_stats.last.fetch("misses")
  end

  test "around the clock session auto-completes after final inner bull hit" do
    user = premium_user("training-auto-complete")
    training_session = user.training_sessions.create!(mode: "around_the_clock", current_target_index: 21)
    login_as(user)

    patch record_training_session_path(training_session), params: { result: "hit", misses: 0 }

    assert_redirected_to training_session_path(training_session)
    training_session.reload
    assert_equal "completed", training_session.status
    assert_not_nil training_session.completed_at
    assert_equal 1, training_session.hits
    assert_equal "Inner Bull", training_session.target_stats.last.fetch("label")
  end

  test "doubles training mode uses double labels and can be abandoned" do
    user = premium_user("training-doubles")
    login_as(user)

    post training_sessions_path, params: { training_session: { mode: "around_the_clock_doubles" } }
    training_session = TrainingSession.order(:created_at).last

    assert_redirected_to training_session_path(training_session)
    assert_equal "D1", training_session.current_target.fetch("label")

    patch record_training_session_path(training_session), params: { result: "hit", misses: 1 }
    assert_redirected_to training_session_path(training_session)
    assert_equal "D2", training_session.reload.current_target.fetch("label")

    patch abandon_training_session_path(training_session)
    assert_redirected_to training_sessions_path
    assert_equal "abandoned", training_session.reload.status
    assert_not_nil training_session.abandoned_at
  end

  test "checkout randomizer records attempts and can be manually completed" do
    user = premium_user("training-checkout")
    login_as(user)

    post training_sessions_path, params: { training_session: { mode: "checkout_randomizer" } }
    training_session = TrainingSession.order(:created_at).last

    assert_redirected_to training_session_path(training_session)
    assert_includes CheckoutCalculator::CHECKOUT_TABLE.keys, training_session.current_target_index
    assert_equal "checkout", training_session.current_target.fetch("kind")
    assert_not_empty training_session.current_target.fetch("suggestion")

    patch record_training_session_path(training_session), params: { result: "hit", misses: 2 }
    assert_redirected_to training_session_path(training_session)

    training_session.reload
    assert_equal "active", training_session.status
    assert_equal 3, training_session.total_darts
    assert_equal 2, training_session.misses
    assert_equal 1, training_session.hits
    assert_equal true, training_session.target_stats.last.fetch("hit")
    assert_includes CheckoutCalculator::CHECKOUT_TABLE.keys, training_session.current_target_index

    patch complete_training_session_path(training_session)
    assert_redirected_to training_sessions_path
    assert_equal "completed", training_session.reload.status
    assert_not_nil training_session.completed_at
  end

  test "training center shows active sessions and filtered completed history" do
    user = premium_user("training-history")
    active = user.training_sessions.create!(mode: "around_the_clock")
    completed = user.training_sessions.create!(mode: "checkout_randomizer", status: "completed", completed_at: Time.current, total_darts: 9, misses: 3, hits: 3)
    user.training_sessions.create!(mode: "around_the_clock_doubles", status: "abandoned", abandoned_at: Time.current)
    login_as(user)

    get training_sessions_path, params: { training_mode: "checkout_randomizer", limit: 5 }

    assert_response :success
    assert_select ".is-active-session", count: 1
    assert_select "a[href='#{training_session_path(active)}']", text: I18n.t("training.resume")
    assert_select "tbody tr", count: 1
    assert_select "tbody td", text: I18n.t("training.modes.checkout_randomizer.name"), count: 1
    assert_select "tbody td", text: completed.total_darts.to_s, count: 1
    assert_select "tbody td", text: I18n.t("training.modes.around_the_clock_doubles.name"), count: 0
  end

  private

  def premium_user(prefix)
    create_user(unique_email(prefix)).tap { |user| user.update!(account_tier: "premium") }
  end
end
