# frozen_string_literal: true

require "system_helper"

class TrainingSessionsSystemTest < ApplicationSystemTestCase
  test "premium user starts and records an around the clock training session through browser UI" do
    login_premium_user("training-browser")

    visit training_sessions_path
    assert_text I18n.t("training.title")

    first(".training-mode-simple-row").click_button I18n.t("training.start")

    assert_current_path %r{/training/}, ignore_query: true
    assert_text I18n.t("training.play_title")
    assert_text I18n.t("training.current_target").upcase
    assert_text "1"

    fill_in "misses", with: "2"
    click_button I18n.t("training.hit")
    assert_selector ".training-target", exact_text: "2"

    training_session = TrainingSession.order(:created_at).last
    assert_equal 1, training_session.reload.current_target_index
    assert_equal 3, training_session.total_darts
    assert_equal 2, training_session.misses
    assert_equal 1, training_session.hits

    assert_text "2"
    assert_text I18n.t("training.darts").upcase
    assert_text "3"
  end

  test "premium user starts checkout randomizer and completes it through browser UI" do
    login_premium_user("training-checkout-browser")

    visit training_sessions_path
    rows = all(".training-mode-simple-row")
    rows.last.click_button I18n.t("training.start")

    assert_current_path %r{/training/}, ignore_query: true
    assert_text I18n.t("training.checkout_score")
    assert_text I18n.t("training.suggested_route").upcase

    click_button I18n.t("training.finish_session")

    assert_current_path training_sessions_path, ignore_query: true
    assert_text I18n.t("training.flashes.completed")
    assert_equal "completed", TrainingSession.order(:created_at).last.status
  end

  private

  def login_premium_user(prefix)
    user = create_user(unique_email(prefix))
    user.update!(account_tier: "premium")

    visit new_session_path
    fill_in "email_address", with: user.email_address
    fill_in "password", with: "password"
    click_button I18n.t("auth.sign_in")

    assert_current_path root_path, ignore_query: true
  end
end
