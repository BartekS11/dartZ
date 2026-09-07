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

  test "live match display swap persists without changing turns scores or local history" do
    visit matches_path

    fill_in "player1_name", with: "Live Alice"
    fill_in "player2_name", with: "Live Bob"
    click_button I18n.t("matches.start_game")
    assert_text "LIVE ALICE"

    match = Match.order(:created_at).last
    original_player_ids = match.players.order(:created_at).pluck(:id)
    original_turn_id = match.current_leg.current_turn.id
    original_scores = original_player_ids.to_h { |id| [ id, match.score_for(Player.find(id)) ] }

    click_button I18n.t("live_match.swap_players")
    within "dialog[open]" do
      assert_text I18n.t("live_match.swap_players_confirm")
      click_button I18n.t("live_match.swap_players")
    end
    assert_text I18n.t("flashes.player_order_swapped")

    assert_equal [ "LIVE BOB", "LIVE ALICE" ], all(".match-score-name").map(&:text)
    assert_equal original_turn_id, match.reload.current_leg.current_turn.id
    assert_equal original_scores, original_player_ids.to_h { |id| [ id, match.score_for(Player.find(id)) ] }

    refresh

    assert_equal [ "LIVE BOB", "LIVE ALICE" ], all(".match-score-name").map(&:text)
    stored_match = page.evaluate_script("JSON.parse(localStorage.getItem('dartz_matches')).find(match => match.id === '#{match.public_id}')")
    assert_equal "Live Bob", stored_match.fetch("player1")
    assert_equal "Live Alice", stored_match.fetch("player2")
  end

  test "only invite host can swap a live display while the invitee is throwing" do
    visit new_registration_path
    fill_in "user_email_address", with: unique_email("live-swap-host")
    fill_in "user_nickname", with: "Live Swap Host"
    fill_in "user_password", with: "password"
    fill_in "user_password_confirmation", with: "password"
    click_button I18n.t("auth.create_account_button")

    fill_in "player1_name", with: "Host Alice"
    click_button I18n.t("matches.create_invite_match")
    assert_current_path %r{/match_invites/}, ignore_query: true

    match = Match.order(:created_at).last
    within ".invite-starter-swap-form" do
      find("button").click
    end

    using_session(:invitee) do
      visit match_invite_join_path(match.invite_token)
      fill_in "player_name", with: "Invitee Bob"
      click_button I18n.t("invites.join_button")
      assert_text "INVITEE BOB"

      assert_no_button I18n.t("live_match.swap_players")
    end

    match.reload
    invitee = match.players.order(:created_at).second
    assert_equal invitee, match.current_player

    visit match_path(match)
    assert_button I18n.t("live_match.swap_players"), disabled: false
    click_button I18n.t("live_match.swap_players")
    within "dialog[open]" do
      click_button I18n.t("live_match.swap_players")
    end
    assert_text I18n.t("flashes.player_order_swapped")

    assert_equal [ "INVITEE BOB", "HOST ALICE" ], all(".match-score-name").map(&:text)
    assert_equal invitee, match.reload.current_player

    using_session(:invitee) do
      assert_equal [ "INVITEE BOB", "HOST ALICE" ], all(".match-score-name").map(&:text)
    end
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
