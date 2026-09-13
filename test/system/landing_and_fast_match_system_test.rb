require "system_helper"

class LandingAndFastMatchSystemTest < ApplicationSystemTestCase
  test "guest moves from the simple landing page into fast match setup" do
    visit root_path(locale: :en)

    assert_text I18n.t("home.title", locale: :en)
    assert_link I18n.t("home.play_now", locale: :en)
    assert_link I18n.t("home.create_account", locale: :en)
    click_link I18n.t("home.play_now", locale: :en)

    assert_current_path matches_path, ignore_query: true
    assert_field "player1_name"
    assert_field "player2_name"
    assert_button I18n.t("matches.start_game", locale: :en)
    assert_selector "details.fast-match-options:not([open])"
  end

  test "fast setup keeps player swapping and progressively reveals full options" do
    visit matches_path(locale: :en)
    fill_in "player1_name", with: "Alice"
    fill_in "player2_name", with: "Bob"

    find(".swap-badge").click
    assert_field "player1_name", with: "Bob"
    assert_field "player2_name", with: "Alice"

    find("details.fast-match-options > summary").click
    assert_selector "details.fast-match-options[open]"
    assert_field "best_of_legs", with: "1"
    assert_field "best_of_sets", with: "1"
    assert_unchecked_field "double_in"
    assert_checked_field "double_out"
    assert_button I18n.t("matches.clear_names", locale: :en)
  end
end
