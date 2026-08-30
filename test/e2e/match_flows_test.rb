# frozen_string_literal: true

require "e2e_helper"

class MatchFlowsTest < E2EIntegrationTest
  test "guest creates match and advances turns through HTTP" do
    match = create_guest_match(player1: "E2E Alice", player2: "E2E Bob", best_of_legs: 1, best_of_sets: 1)

    assert_redirected_to match_path(match)
    assert_equal [ "E2E Alice", "E2E Bob" ], match.players.order(:created_at).pluck(:name)

    first_turn = match.reload.current_leg.current_turn
    assert_equal "E2E Alice", first_turn.player.name

    submit_turn_total(first_turn, 60)
    assert_response :redirect

    match.reload
    assert_equal 441, match.score_for(first_turn.player)
    assert_equal "E2E Bob", match.current_leg.current_turn.player.name
  end

  test "registered user signs in and creates an owned match" do
    email = unique_email("registered-flow")

    post registration_path, params: {
      user: {
        email_address: email,
        nickname: "E2E Registered",
        password: "password",
        password_confirmation: "password"
      }
    }
    assert_redirected_to matches_path

    user = User.find_by!(email_address: email)
    assert_equal "E2E Registered", user.nickname

    post matches_path, params: {
      player1_name: "E2E Registered",
      player2_name: "Opponent",
      best_of_legs: 1,
      best_of_sets: 1
    }

    match = Match.order(:created_at).last
    assert_redirected_to match_path(match)
    assert match.players.exists?(user: user, name: "E2E Registered")
  end

  test "invite starter can be swapped over HTTP before invitee joins" do
    user = create_user(unique_email("invite-http-swap-owner"))
    login_as(user)

    post match_invites_path, params: {
      player1_name: "HTTP Swap Owner",
      best_of_legs: 1,
      best_of_sets: 1,
      invite_starter: "owner"
    }

    match = Match.order(:created_at).last
    assert_equal 1, match.starting_player_position

    patch match_invite_starter_path(match), params: { invite_starter: "invitee" }
    assert_redirected_to match_invite_path(match)
    assert_equal 2, match.reload.starting_player_position

    open_session do |guest|
      guest.post accept_match_invite_path(match.invite_token), params: { player_name: "HTTP Swap Invitee" }
      guest.assert_response :redirect
    end

    assert_equal "HTTP Swap Invitee", match.reload.current_leg.current_turn.player.name
  end

  test "invite match can be joined and enforces remote turn ownership" do
    user = create_user(unique_email("invite-owner"))
    login_as(user)

    post match_invites_path, params: {
      player1_name: "Owner",
      best_of_legs: 1,
      best_of_sets: 1,
      invite_starter: "owner"
    }

    match = Match.order(:created_at).last
    assert_redirected_to match_invite_path(match)
    assert match.invite_token.present?

    open_session do |guest|
      guest.get match_invite_join_path(match.invite_token)
      guest.assert_response :success
      guest.post accept_match_invite_path(match.invite_token), params: { player_name: "Invitee" }
      guest.assert_response :redirect
    end

    match.reload
    assert_equal 2, match.players.count
    owner_player = match.players.order(:created_at).first
    invitee = match.players.order(:created_at).second
    current_turn = match.current_leg.current_turn

    assert_equal owner_player, current_turn.player

    post turn_throws_path(current_turn), params: {
      actor_player_id: invitee.public_id,
      throw: { total: 60 }
    }
    assert_response :redirect
    assert_equal 501, match.reload.score_for(owner_player), "wrong invite participant must not be able to score another player's turn"

    post turn_throws_path(current_turn), params: {
      actor_player_id: owner_player.public_id,
      throw: { total: 60 }
    }
    assert_response :redirect
    assert_equal 441, match.reload.score_for(owner_player)
  end

  test "invite status updates after invitee joins and invitee can start when selected" do
    user = create_user(unique_email("invite-status-owner"))
    login_as(user)

    post match_invites_path, params: {
      player1_name: "Starter Owner",
      best_of_legs: 1,
      best_of_sets: 1,
      invite_starter: "invitee"
    }

    match = Match.order(:created_at).last
    get match_invite_status_path(match)
    assert_response :success
    assert_equal false, json_response.fetch("joined")
    assert_nil json_response.fetch("match_url")

    open_session do |guest|
      guest.post accept_match_invite_path(match.invite_token), params: { player_name: "Starting Invitee" }
      guest.assert_response :redirect
    end

    match.reload
    invitee = match.players.order(:created_at).second
    assert_equal invitee, match.current_leg.current_turn.player

    get match_invite_status_path(match)
    assert_response :success
    assert_equal true, json_response.fetch("joined")
    assert_includes json_response.fetch("match_url"), match_path(match)
  end

  test "invite cannot be joined twice and cancelled invite is gone" do
    user = create_user(unique_email("invite-full-owner"))
    login_as(user)

    post match_invites_path, params: {
      player1_name: "Owner",
      best_of_legs: 1,
      best_of_sets: 1
    }

    match = Match.order(:created_at).last

    open_session do |guest|
      guest.post accept_match_invite_path(match.invite_token), params: { player_name: "First Invitee" }
      guest.assert_response :redirect
    end

    open_session do |second_guest|
      second_guest.get match_invite_join_path(match.invite_token)
      second_guest.assert_response :conflict
      second_guest.assert_match "First Invitee", match.reload.players.order(:created_at).second.name
      second_guest.assert_equal 2, match.players.count
    end

    post match_invites_path, params: {
      player1_name: "Cancel Owner",
      best_of_legs: 1,
      best_of_sets: 1
    }

    cancelled_match = Match.order(:created_at).last
    delete cancel_match_invite_path(cancelled_match)
    assert_response :redirect

    open_session do |guest|
      guest.get match_invite_join_path(cancelled_match.invite_token)
      guest.assert_response :gone
    end
  end

  test "bot match can be created by signed in user" do
    user = create_user(unique_email("bot-owner"))
    login_as(user)

    assert_difference("Match.count", 1) do
      post bot_match_path, params: {
        player_name: "Human",
        bot_name: "Botty",
        bot_level: 10,
        best_of_legs: 1,
        best_of_sets: 1
      }
    end

    match = Match.order(:created_at).last
    assert_redirected_to match_path(match)
    assert match.players.exists?(bot: true, name: "Botty")
    assert_not_nil match.current_leg.current_turn
  end

  test "best of three legs continues after first leg and finishes after second won leg" do
    match = create_guest_match(
      player1: "Leg Winner",
      player2: "Leg Opponent",
      best_of_legs: 3,
      best_of_sets: 1,
      starting_score: 101,
      double_out: true
    )
    player1 = match.players.order(:created_at).first

    win_current_leg_for(match, player1)

    assert_equal 1, match.match_sets.count
    assert_equal 2, match.legs.count
    assert_equal 1, match.match_sets.first.legs_won_by(player1)
    refute match.finished?
    assert_equal 101, match.score_for(player1)

    win_current_leg_for(match, player1)

    assert match.finished?
    assert_equal 2, match.legs.where(winner_id: player1.id).count
    assert_equal player1, match.match_sets.order(:created_at).last.winner
  end

  test "best of three sets creates next set and finishes after second won set" do
    match = create_guest_match(
      player1: "Set Winner",
      player2: "Set Opponent",
      best_of_legs: 1,
      best_of_sets: 3,
      starting_score: 101,
      double_out: true
    )
    player1 = match.players.order(:created_at).first

    win_current_leg_for(match, player1)

    assert_equal 2, match.match_sets.count
    assert_equal 1, match.match_sets.where(winner_id: player1.id).count
    refute match.finished?
    assert_equal 101, match.score_for(player1)

    win_current_leg_for(match, player1)

    assert match.finished?
    assert_equal 2, match.match_sets.where(winner_id: player1.id).count
    assert_equal 2, match.legs.where(winner_id: player1.id).count
  end

  test "scoring rules cover busts and double-out checkout through HTTP" do
    match = create_guest_match(player1: "Checkout", player2: "Opponent", best_of_legs: 1, best_of_sets: 1, starting_score: 301, double_out: true)
    player = match.players.order(:created_at).first

    # Bring first player from 301 to 40 over alternating turns.
    submit_turn_total(match.reload.current_leg.current_turn, 180)
    submit_turn_total(match.reload.current_leg.current_turn, 0)
    submit_turn_total(match.reload.current_leg.current_turn, 81)
    submit_turn_total(match.reload.current_leg.current_turn, 0)
    assert_equal 40, match.reload.score_for(player)

    bust_turn = match.current_leg.current_turn
    post turn_throws_path(bust_turn), params: { throw: { segment: 20, multiplier: "triple" } }
    assert_response :redirect
    assert_equal 40, match.reload.score_for(player), "bust should reset to previous score"
    refute match.current_leg.finished?

    submit_turn_total(match.current_leg.current_turn, 0)
    checkout_turn = match.reload.current_leg.current_turn
    post turn_throws_path(checkout_turn), params: { throw: { segment: 20, multiplier: "double" } }
    assert_response :redirect

    assert match.reload.finished?
    finished_leg_player = match.legs.order(:created_at).last.leg_players.find_by!(player: player)
    assert_equal 0, finished_leg_player.score
  end
end
