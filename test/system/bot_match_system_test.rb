# frozen_string_literal: true

require "system_helper"

class BotMatchSystemTest < ApplicationSystemTestCase
  test "signed in user creates bot match from simplified setup page" do
    user = create_user(unique_email("bot-system"))
    login_user(user)

    visit new_bot_match_path

    assert_text I18n.t("bot_matches.practice")
    assert_text I18n.t("bot_matches.level_help")
    refute_text I18n.t("bot_matches.learning_pace")
    assert_selector "input[name='bot_level']", count: 10, visible: :all

    fill_in "player_name", with: "Browser Human"
    fill_in "bot_name", with: "Browser Bot"
    choose "bot_level_10", allow_label_click: true
    select "301", from: "starting_score"
    select "Bo3", from: "best_of_legs"
    click_button I18n.t("bot_matches.start_practice")

    assert_current_path %r{/matches/}, ignore_query: true
    assert_text "BROWSER HUMAN"
    match = Match.order(:created_at).last
    assert_text "BROWSER BOT"
    assert_equal 10, match.players.find_by!(bot: true).bot_level
    assert_equal 301, match.starting_score
    assert_equal 3, match.best_of_legs
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
