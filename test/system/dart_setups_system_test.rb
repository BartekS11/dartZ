# frozen_string_literal: true

require "system_helper"

class DartSetupsSystemTest < ApplicationSystemTestCase
  test "premium user changes dart setup through browser UI" do
    user = login_premium_user("dart-setup-browser-save")

    visit edit_dart_setup_path

    assert_text I18n.t("dart_setup.title")
    assert_text I18n.t("dart_setup.default_ready")

    choose "dart_setup_manufacturer_target", allow_label_click: true
    fill_in "dart_setup_weight_g", with: "24.2"
    choose "dart_setup_shaft_type_carbon", allow_label_click: true
    fill_in "dart_setup_shaft_length_mm", with: "42"
    fill_in "dart_setup_point_length_mm", with: "35"
    click_button "Save setup"

    assert_current_path edit_dart_setup_path, ignore_query: true
    assert_text I18n.t("flashes.dart_setup_saved")
    assert_text "Target"
    assert_text "24.2g"
    assert_text "Carbon"

    setup = user.reload.dart_setup
    assert_equal "target", setup.manufacturer
    assert_equal BigDecimal("24.2"), setup.weight_g
    assert_equal "carbon", setup.shaft_type
    assert_equal 42, setup.shaft_length_mm
    assert_equal 35, setup.point_length_mm
  end

  test "premium user applies saved setup snapshot as current default through browser UI" do
    user = premium_user("dart-setup-browser-use-saved")
    saved_setup = user.create_dart_setup!(
      manufacturer: "target",
      weight_g: 24.0,
      shaft_type: "carbon",
      shaft_length_mm: 42,
      point_length_mm: 35
    )
    create_match_with_snapshot(user, saved_setup)
    user.dart_setup.update!(
      manufacturer: "winmau",
      weight_g: 23.0,
      shaft_type: "nylon",
      shaft_length_mm: 40,
      point_length_mm: 32
    )

    login_user(user)
    visit edit_dart_setup_path

    assert_text saved_setup.display_summary
    click_button "Use setup"

    assert_current_path edit_dart_setup_path, ignore_query: true
    assert_text I18n.t("flashes.saved_setup_selected")
    assert_text "Target"
    assert_text "24g"
    assert_text "Carbon"

    setup = user.reload.dart_setup
    assert_equal "target", setup.manufacturer
    assert_equal BigDecimal("24.0"), setup.weight_g
    assert_equal "carbon", setup.shaft_type
  end

  private

  def premium_user(prefix)
    create_user(unique_email(prefix)).tap { |user| user.update!(account_tier: "premium") }
  end

  def login_premium_user(prefix)
    premium_user(prefix).tap { |user| login_user(user) }
  end

  def login_user(user)
    visit new_session_path
    fill_in "email_address", with: user.email_address
    fill_in "password", with: "password"
    click_button I18n.t("auth.sign_in")

    assert_current_path root_path, ignore_query: true
  end

  def create_match_with_snapshot(user, setup)
    match = MatchCreator.call(
      settings: MatchSettings.new(best_of_legs: 1, best_of_sets: 1, starting_score: 501, double_in: false, double_out: true),
      players: [
        { name: "Setup Owner", user: user, dart_setup: setup },
        { name: "Opponent" }
      ]
    )
    ThrowSubmission.call(turn: match.current_leg.current_turn, total: 60)
  end
end
