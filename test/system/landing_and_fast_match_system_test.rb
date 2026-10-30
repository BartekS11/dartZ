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

  [ [1400, 1400], [390, 844] ].each do |width, height|
    test "start button follows expanded options and returns when collapsed at #{width}px" do
      page.current_window.resize_to(width, height)
      visit matches_path(locale: :en)
      fill_in "player1_name", with: "Alice"
      fill_in "player2_name", with: "Bob"

      assert_selector ".fast-match-submit + details.fast-match-options:not([open])"
      find("details.fast-match-options > summary").click
      assert_selector "details.fast-match-options[open] + .fast-match-submit"
      assert_selector ".fast-start-button", count: 1
      assert page.evaluate_script("document.querySelector('.fast-start-button').getBoundingClientRect().top >= document.querySelector('.fast-match-options').getBoundingClientRect().bottom")
      fill_in "best_of_legs", with: "3"

      find("details.fast-match-options > summary").click
      assert_selector ".fast-match-submit + details.fast-match-options:not([open])"
      find("details.fast-match-options > summary").click
      assert_selector "details.fast-match-options[open] + .fast-match-submit"
      assert_field "best_of_legs", with: "3"

      click_button I18n.t("matches.start_game", locale: :en)
      assert_current_path %r{/matches/[^/]+$}, ignore_query: true
      assert_equal 3, Match.order(:created_at).last.best_of_legs
    ensure
      page.current_window.resize_to(1400, 1400)
    end
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
    assert_field "Legs per set", with: "1"
    assert_field "Sets per match", with: "1"
    within ".fast-options-body" do
      assert_selector "button.legs-preset", text: "Best of 3"
      assert_selector "button.sets-preset", text: "Best of 5"
    end
    assert_unchecked_field "double_in"
    assert_checked_field "double_out"
    assert_button I18n.t("matches.clear_names", locale: :en)
  end
end
