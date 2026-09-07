# frozen_string_literal: true

require "system_helper"

class StatsAndPracticePlansSystemTest < ApplicationSystemTestCase
  test "logged in free user opens stats from nav and sees empty chart-ready dashboard" do
    user = create_user(unique_email("stats-system-free"))
    login_user(user)

    click_link I18n.t("nav.stats")

    assert_current_path stats_path, ignore_query: true
    assert_text I18n.t("stats.title")
    assert_text I18n.t("stats.empty")
  end

  test "premium user starts practice plan and manually completes first task" do
    user = create_user(unique_email("plans-system-premium"))
    user.update!(account_tier: "premium")
    login_user(user)

    visit training_sessions_path
    click_link I18n.t("nav.practice_plans")

    assert_current_path practice_plans_path, ignore_query: true
    assert_text I18n.t("practice_plans.title")

    click_button I18n.t("practice_plans.generate")
    assert_current_path %r{/practice_plans/[^/?]+}, ignore_query: true

    plan = PracticePlan.order(:created_at).last
    assert_current_path practice_plan_path(plan), ignore_query: true
    assert_text plan.title

    click_button I18n.t("practice_plans.mark_done"), match: :first

    assert_text I18n.t("practice_plans.flashes.task_completed")
    assert_operator plan.reload.progress_percent, :>, 0
  end

  private

  def login_user(user)
    visit new_session_path
    fill_in "email_address", with: user.email_address
    fill_in "password", with: "password"
    click_button I18n.t("auth.sign_in")

    assert_current_path root_path, ignore_query: true
  end
end
