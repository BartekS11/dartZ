# frozen_string_literal: true

require "system_helper"

class RegistrationAndTournamentSystemTest < ApplicationSystemTestCase
  test "user registers through browser UI" do
    visit new_registration_path

    fill_in "user_email_address", with: unique_email("browser-user")
    fill_in "user_nickname", with: "Browser User"
    fill_in "user_password", with: "password"
    fill_in "user_password_confirmation", with: "password"
    click_button I18n.t("auth.create_account_button")

    assert_current_path matches_path, ignore_query: true
    assert_text I18n.t("matches.new_game")
  end

  test "guest creates tournament through browser UI" do
    visit new_tournament_path

    fill_in "tournament_title", with: "Browser Tournament"
    select "Playoffs", from: "tournament_format_type"
    fill_in "tournament_best_of_legs", with: "1"
    fill_in "tournament_best_of_sets", with: "1"
    fill_in "tournament_entry_names", with: "Alpha\nBravo"
    click_button I18n.t("tournaments.create")

    assert_text "Browser Tournament"
    assert_current_path %r{/tournaments/}, ignore_query: false
  end
end
