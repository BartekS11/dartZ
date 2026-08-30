# frozen_string_literal: true

require "e2e_helper"

class DartSetupsFlowTest < E2EIntegrationTest
  test "free user cannot open or update dart setup" do
    user = create_user(unique_email("dart-setup-free"))
    login_as(user)

    get edit_dart_setup_path
    assert_redirected_to matches_path
    assert_equal I18n.t("flashes.premium_required"), flash[:alert]

    assert_no_difference("DartSetup.count") do
      patch dart_setup_path, params: { dart_setup: setup_params(manufacturer: "target") }
    end

    assert_redirected_to matches_path
  end

  test "premium user sees default setup values then saves changed setup" do
    user = premium_user("dart-setup-save")
    login_as(user)

    get edit_dart_setup_path
    assert_response :success
    assert_nil user.reload.dart_setup, "opening the default setup form should not persist until saved"
    assert_select "input[name='dart_setup[manufacturer]'][value='winmau'][checked]"
    assert_select "input#dart_setup_weight_g[value='23.0']"
    assert_select "input#dart_setup_shaft_length_mm[value='40']"
    assert_select "input#dart_setup_point_length_mm[value='32']"

    assert_difference("DartSetup.count", 1) do
      patch dart_setup_path, params: {
        dart_setup: setup_params(
          manufacturer: "target",
          weight_g: 24.2,
          shaft_type: "carbon",
          shaft_length_mm: 42,
          point_length_mm: 35
        )
      }
    end

    assert_redirected_to edit_dart_setup_path
    assert_equal I18n.t("flashes.dart_setup_saved"), flash[:notice]

    setup = user.reload.dart_setup
    assert_equal "target", setup.manufacturer
    assert_equal BigDecimal("24.2"), setup.weight_g
    assert_equal "carbon", setup.shaft_type
    assert_equal 42, setup.shaft_length_mm
    assert_equal 35, setup.point_length_mm
  end

  test "premium user changes an existing default setup without creating another setup" do
    user = premium_user("dart-setup-change-default")
    existing_setup = user.create_dart_setup!(setup_params)
    login_as(user)

    assert_no_difference("DartSetup.count") do
      patch dart_setup_path, params: {
        dart_setup: setup_params(
          manufacturer: "harrows",
          weight_g: 25.0,
          shaft_type: "hybrid",
          shaft_length_mm: 45,
          point_length_mm: 38
        )
      }
    end

    assert_redirected_to edit_dart_setup_path
    setup = existing_setup.reload
    assert_equal "harrows", setup.manufacturer
    assert_equal BigDecimal("25.0"), setup.weight_g
    assert_equal "hybrid", setup.shaft_type
    assert_equal 45, setup.shaft_length_mm
    assert_equal 38, setup.point_length_mm
  end

  test "saved setup snapshots from previous matches can become the current default" do
    user = premium_user("dart-setup-use-saved")
    saved_setup = user.create_dart_setup!(
      manufacturer: "target",
      weight_g: 24.0,
      shaft_type: "carbon",
      shaft_length_mm: 42,
      point_length_mm: 35
    )
    match = MatchCreator.call(
      settings: MatchSettings.new(best_of_legs: 1, best_of_sets: 1, starting_score: 501, double_in: false, double_out: true),
      players: [
        { name: "Setup Owner", user: user, dart_setup: saved_setup },
        { name: "Opponent" }
      ]
    )
    submit_turn_total(match.current_leg.current_turn, 60)
    user.dart_setup.update!(setup_params)
    login_as(user)

    get edit_dart_setup_path
    assert_response :success
    assert_includes response.body, saved_setup.display_summary

    patch use_saved_dart_setup_path, params: { fingerprint: saved_setup.fingerprint }

    assert_redirected_to edit_dart_setup_path
    assert_equal I18n.t("flashes.saved_setup_selected"), flash[:notice]

    setup = user.reload.dart_setup
    assert_equal "target", setup.manufacturer
    assert_equal BigDecimal("24.0"), setup.weight_g
    assert_equal "carbon", setup.shaft_type
    assert_equal 42, setup.shaft_length_mm
    assert_equal 35, setup.point_length_mm
  end

  test "missing saved setup fingerprint redirects with alert" do
    user = premium_user("dart-setup-missing-saved")
    user.create_dart_setup!(setup_params)
    login_as(user)

    patch use_saved_dart_setup_path, params: { fingerprint: "does-not-exist" }

    assert_redirected_to edit_dart_setup_path
    assert_equal I18n.t("flashes.saved_setup_not_found"), flash[:alert]
  end

  private

  def premium_user(prefix)
    create_user(unique_email(prefix)).tap { |user| user.update!(account_tier: "premium") }
  end

  def setup_params(manufacturer: "winmau", weight_g: 23.0, shaft_type: "nylon", shaft_length_mm: 40, point_length_mm: 32)
    {
      manufacturer: manufacturer,
      weight_g: weight_g,
      shaft_type: shaft_type,
      shaft_length_mm: shaft_length_mm,
      point_length_mm: point_length_mm
    }
  end
end
