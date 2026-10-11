require "test_helper"

class TrainingSessionsControllerTest < ActionDispatch::IntegrationTest
  test "requires login" do
    get training_sessions_path

    assert_redirected_to new_session_path
  end

  test "free user can see basic saved training insights but cannot start sessions" do
    user = create_user("free-training@example.com")
    login_as(user)

    get training_sessions_path

    assert_response :success
    assert_select "p", text: /basic progress from your saved training history/
    assert_select "h2", text: "Choose mode", count: 0

    assert_no_difference("TrainingSession.count") do
      post training_sessions_path, params: { training_session: { mode: "around_the_clock" } }
    end
    assert_redirected_to billing_path
  end

  test "free user can see retained session summaries" do
    user = create_user("free-history@example.com")
    user.training_sessions.create!(mode: "around_the_clock", status: "completed", total_darts: 60)
    login_as(user)

    get training_sessions_path

    assert_response :success
    assert_select "td", text: "Around the Clock"
    assert_select "td a", count: 0
  end

  test "premium user can view training center" do
    user = create_user("premium-training@example.com")
    user.update!(account_tier: "premium")
    login_as(user)

    get training_sessions_path

    assert_response :success
    assert_select "h1", "Training Center"
    assert_select "h3", text: "Pro training focus", count: 0
  end

  test "pro user sees an insufficient data state until enough sessions exist" do
    user = create_user("pro-recommendations@example.com")
    user.update!(account_tier: "pro")
    login_as(user)

    get training_sessions_path

    assert_response :success
    assert_select "h3", text: "Pro training focus"
    assert_select "p", text: /Complete more training sessions/
  end

  test "pro recommendations identify modes with declining recent averages" do
    user = create_user("pro-training-focus@example.com")
    user.update!(account_tier: "pro")
    10.times do |index|
      user.training_sessions.create!(
        mode: "around_the_clock",
        status: "completed",
        total_darts: index < 5 ? 50 : 40,
        created_at: index.days.ago
      )
    end
    login_as(user)

    get training_sessions_path

    assert_response :success
    assert_select "p", text: /Across 10 sessions, your recent average increased by 10.0 darts/
  end

  test "pro user can start around the clock" do
    user = create_user("pro-training@example.com")
    user.update!(account_tier: "pro")
    login_as(user)

    assert_difference("TrainingSession.count", 1) do
      post training_sessions_path, params: { training_session: { mode: "around_the_clock" } }
    end

    assert_redirected_to training_session_path(TrainingSession.last)
  end

  test "records hit with misses" do
    user = create_user("record-training@example.com")
    user.update!(account_tier: "premium")
    training_session = user.training_sessions.create!(mode: "around_the_clock")
    login_as(user)

    patch record_training_session_path(training_session), params: { result: "hit", misses: 2 }

    assert_redirected_to training_session_path(training_session)
    training_session.reload
    assert_equal 1, training_session.current_target_index
    assert_equal 3, training_session.total_darts
    assert_equal 2, training_session.misses
  end

  test "records no hit" do
    user = create_user("nohit-training@example.com")
    user.update!(account_tier: "premium")
    training_session = user.training_sessions.create!(mode: "around_the_clock")
    login_as(user)

    patch record_training_session_path(training_session), params: { result: "no_hit", misses: 3 }

    assert_redirected_to training_session_path(training_session)
    training_session.reload
    assert_equal 0, training_session.current_target_index
    assert_equal 3, training_session.total_darts
    assert_equal 3, training_session.misses
  end

  test "abandon active session" do
    user = create_user("abandon-training@example.com")
    user.update!(account_tier: "premium")
    training_session = user.training_sessions.create!(mode: "around_the_clock")
    login_as(user)

    patch abandon_training_session_path(training_session)

    assert_redirected_to training_sessions_path
    assert_equal "abandoned", training_session.reload.status
  end
end
