# frozen_string_literal: true

require "e2e_helper"

class StatsAndPracticePlansFlowTest < E2EIntegrationTest
  test "free logged in user can view filtered stats dashboard with charts" do
    user = create_user(unique_email("stats-free"))
    match = MatchCreator.call(
      settings: MatchSettings.new(best_of_legs: 1, best_of_sets: 1, starting_score: 101, double_in: false, double_out: true),
      players: [ { name: "Stats User", user: user }, { name: "Stats Bot", bot: true, bot_level: 5 } ]
    )
    player = match.players.find_by!(user: user)
    ThrowSubmission.call(turn: match.current_leg.current_turn, total: 61)
    ThrowSubmission.call(turn: match.reload.current_leg.current_turn, total: 0)
    ThrowSubmission.call(turn: match.reload.current_leg.current_turn, throw_attributes: { segment: 20, multiplier: "double" })
    assert_equal player, match.reload.winner
    login_as(user)

    get stats_path, params: { starting_score: 101, opponent_type: "bot", match_source: "casual" }

    assert_response :success
    assert_select "h1", I18n.t("stats.title")
    assert_select ".stats-metric-label", text: I18n.t("stats.matches_played")
    assert_select ".stats-metric-label", text: I18n.t("stats.checkout_rate")
    assert_select "h2", text: I18n.t("stats.charts")
    assert_includes response.body, I18n.t("stats.average_over_time")
  end

  test "stats dashboard has empty state for logged in user without matches" do
    user = create_user(unique_email("stats-empty"))
    login_as(user)

    get stats_path

    assert_response :success
    assert_includes response.body, I18n.t("stats.empty")
  end

  test "free user cannot access premium practice plans" do
    user = create_user(unique_email("plans-free"))
    login_as(user)

    get practice_plans_path

    assert_redirected_to matches_path
    assert_equal I18n.t("flashes.premium_required"), flash[:alert]
  end

  test "premium user starts multiple predefined practice plans and manually completes a task" do
    user = premium_user("plans-predefined")
    login_as(user)

    post practice_plans_path, params: { template_key: "checkout_improvement" }
    first_plan = PracticePlan.order(:created_at).last
    assert_redirected_to practice_plan_path(first_plan)

    post practice_plans_path, params: { template_key: "doubles_improvement" }
    second_plan = PracticePlan.order(:created_at).last
    assert_redirected_to practice_plan_path(second_plan)

    assert_equal 2, user.practice_plans.active.count

    task = first_plan.tasks.first
    patch practice_plan_complete_task_path(first_plan, task)

    assert_redirected_to practice_plan_path(first_plan)
    assert_equal task.target_count, task.reload.progress_count
    assert_equal "completed", first_plan.reload.status
  end

  test "completed training session automatically progresses matching active practice plan" do
    user = premium_user("plans-auto-progress")
    plan = PracticePlanStarter.from_template(user: user, template_key: "checkout_improvement")
    task = plan.tasks.first
    training_session = user.training_sessions.create!(mode: "checkout_randomizer")
    login_as(user)

    patch complete_training_session_path(training_session)

    assert_redirected_to training_sessions_path
    assert_equal 1, task.reload.progress_count
    assert_equal "active", plan.reload.status
  end

  test "generated practice plan uses weak stats recommendation" do
    user = premium_user("plans-generated")
    login_as(user)

    post practice_plans_path, params: { generated: "1" }

    plan = PracticePlan.order(:created_at).last
    assert_redirected_to practice_plan_path(plan)
    assert_equal "generated", plan.plan_type
    assert_equal "checkout_improvement", plan.recommendation_metadata.fetch("recommended_from")
    assert_equal "checkout_randomizer", plan.tasks.first.training_mode
  end

  test "premium user creates custom practice plan from existing training modes" do
    user = premium_user("plans-custom")
    login_as(user)

    post practice_plans_path, params: {
      title: "My Doubles Work",
      tasks: {
        "0" => { training_mode: "around_the_clock_doubles", target_count: 2 },
        "1" => { training_mode: "checkout_randomizer", target_count: 1 }
      }
    }

    plan = PracticePlan.order(:created_at).last
    assert_redirected_to practice_plan_path(plan)
    assert_equal "custom", plan.plan_type
    assert_equal "My Doubles Work", plan.title
    assert_equal [ "around_the_clock_doubles", "checkout_randomizer" ], plan.tasks.pluck(:training_mode)
    assert_equal [ 2, 1 ], plan.tasks.pluck(:target_count)
  end

  private

  def premium_user(prefix)
    create_user(unique_email(prefix)).tap { |user| user.update!(account_tier: "premium") }
  end
end
