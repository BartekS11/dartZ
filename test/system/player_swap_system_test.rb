# frozen_string_literal: true

require "system_helper"

class PlayerSwapSystemTest < ApplicationSystemTestCase
  test "normal match lobby swap button swaps player names before creating match" do
    visit matches_path

    fill_in "player1_name", with: "Swap Alice"
    fill_in "player2_name", with: "Swap Bob"
    click_button "⇄"

    assert_field "player1_name", with: "Swap Bob"
    assert_field "player2_name", with: "Swap Alice"

    click_button I18n.t("matches.start_game")

    assert_text "SWAP BOB"
    assert_text "SWAP ALICE"

    match = Match.order(:created_at).last
    assert_equal [ "Swap Bob", "Swap Alice" ], match.players.order(:created_at).pluck(:name)
  end

  test "invite match starter swap changes who throws first before invitee joins" do
    visit new_registration_path

    fill_in "user_email_address", with: unique_email("invite-swap-owner")
    fill_in "user_nickname", with: "Invite Swap Owner"
    fill_in "user_password", with: "password"
    fill_in "user_password_confirmation", with: "password"
    click_button I18n.t("auth.create_account_button")

    assert_current_path matches_path, ignore_query: true

    fill_in "player1_name", with: "Invite Owner"
    click_button I18n.t("matches.create_invite_match")

    assert_current_path %r{/match_invites/}, ignore_query: true
    assert_text "Invite Owner"
    assert_text I18n.t("invites.invited_player")

    match = Match.order(:created_at).last
    assert_equal 1, match.starting_player_position

    within ".invite-starter-swap-form" do
      find("button").click
    end

    assert_text I18n.t("invites.first_to_throw", player: I18n.t("invites.invited_player"))
    assert_equal 2, match.reload.starting_player_position
    assert_text I18n.t("invites.first_to_throw", player: I18n.t("invites.invited_player"))
  end
end
