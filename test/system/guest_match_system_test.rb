# frozen_string_literal: true

require "system_helper"

class GuestMatchSystemTest < ApplicationSystemTestCase
  test "guest creates match through browser UI" do
    visit matches_path

    fill_in "player1_name", with: "Browser Alice"
    fill_in "player2_name", with: "Browser Bob"
    click_button I18n.t("matches.start_game")

    assert_text "BROWSER ALICE"
    assert_text "BROWSER BOB"
    assert_current_path %r{/matches/}, ignore_query: true
  end
end
