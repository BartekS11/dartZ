require "test_helper"

class MatchPlayerOrdersControllerTest < ActionDispatch::IntegrationTest
  test "guest viewer swaps the active thrower without changing display order" do
    match, alice, bob = started_guest_match
    turn_id = match.current_leg.current_turn.id
    Turbo::StreamsChannel.expects(:broadcast_replace_to).once
    Turbo::StreamsChannel.expects(:broadcast_update_to).once

    patch match_player_order_path(match), params: { guest_token: match.guest_token }

    assert_response :see_other
    assert_redirected_to match_path(match)
    assert_equal [ alice, bob ], MatchStatePresenter.new(match.reload).players
    assert_equal bob, match.current_player
    assert_equal turn_id, match.current_leg.current_turn.id
    assert_equal I18n.t("flashes.player_order_swapped"), flash[:notice]
  end

  test "request without match access cannot swap" do
    match, alice, = started_guest_match

    patch match_player_order_path(match)

    assert_redirected_to matches_path
    assert_equal alice, match.reload.current_player
  end

  test "invite host can swap while the invitee is set to throw" do
    host = create_user("swap-controller-host@example.com")
    match, host_player, invitee = started_invite_match(host: host)
    match.current_leg.current_turn.update!(player: invitee)
    login_as(host)

    patch match_player_order_path(match)

    assert_response :see_other
    assert_equal host_player, match.reload.current_player
    assert match.invite_host?(host)
  end

  test "invitee cannot swap" do
    host = create_user("swap-controller-host-denied@example.com")
    invitee_user = create_user("swap-controller-invitee@example.com")
    match, host_player, invitee = started_invite_match(host: host)
    invitee.update!(user: invitee_user)
    login_as(invitee_user)

    patch match_player_order_path(match)

    assert_response :see_other
    assert_redirected_to match_path(match)
    assert_equal host_player, match.reload.current_player
    assert_equal I18n.t("flashes.player_order_host_only"), flash[:alert]
  end

  test "signed-in player can swap the active thrower to a bot" do
    user = create_user("swap-controller-bot@example.com")
    match = Match.create!
    human = match.players.create!(name: "Human", user: user)
    bot = match.players.create!(name: "Bot", bot: true, bot_level: 10)
    match.start_first_set!
    login_as(user)

    patch match_player_order_path(match)

    assert_response :see_other
    assert_equal [ human, bot ], match.reload.players_in_display_order.to_a
    assert_equal bot, match.current_player
  end

  test "authorized tournament match viewer can swap the active thrower" do
    match, alice, bob = started_guest_match
    tournament = Tournament.create!(title: "Swap Cup", format_type: "playoffs")
    home = tournament.entries.create!(name: "Alice")
    away = tournament.entries.create!(name: "Bob")
    round = tournament.rounds.create!(number: 1, name: "Final", stage_type: "playoffs", status: "active")
    round.tournament_matches.create!(tournament: tournament, home_entry: home, away_entry: away, linked_match: match, status: "live")

    patch match_player_order_path(match), params: { guest_token: match.guest_token }

    assert_response :see_other
    assert_equal [ alice, bob ], match.reload.players_in_display_order.to_a
    assert_equal bob, match.current_player
  end

  test "request after a dart is entered is rejected" do
    match, alice, = started_guest_match
    ThrowSubmission.call(
      turn: match.current_leg.current_turn,
      throw_attributes: { segment: 20, multiplier: "single" }
    )

    patch match_player_order_path(match), params: { guest_token: match.guest_token }

    assert_response :see_other
    assert_equal alice, match.reload.current_player
    assert_equal I18n.t("flashes.player_order_unavailable"), flash[:alert]
  end

  test "request from turn four is rejected" do
    match, = started_guest_match
    3.times do
      ThrowSubmission.call(turn: match.reload.current_leg.current_turn, total: 0)
    end
    current_player = match.reload.current_player

    patch match_player_order_path(match), params: { guest_token: match.guest_token }

    assert_response :see_other
    assert_equal current_player, match.reload.current_player
    assert_equal I18n.t("flashes.player_order_unavailable"), flash[:alert]
  end

  test "unstarted finished and non-two-player matches reject direct requests" do
    [ unstarted_match, finished_match, three_player_match ].each do |match|
      original_player = match.current_player

      patch match_player_order_path(match), params: { guest_token: match.guest_token }

      assert_response :see_other
      assert_redirected_to match_path(match)
      if original_player
        assert_equal original_player, match.reload.current_player
      else
        assert_nil match.reload.current_player
      end
      assert_equal I18n.t("flashes.player_order_unavailable"), flash[:alert]
    end
  end

  private
    def started_guest_match
      match = Match.create!(guest_token: SecureRandom.hex(24))
      alice = match.players.create!(name: "Alice")
      bob = match.players.create!(name: "Bob")
      match.start_first_set!
      [ match, alice, bob ]
    end

    def started_invite_match(host:)
      match, host_player, invitee = started_guest_match
      match.update!(invite_token: SecureRandom.urlsafe_base64(24), invite_joined_at: Time.current)
      host_player.update!(user: host)
      [ match, host_player, invitee ]
    end

    def unstarted_match
      match = Match.create!(guest_token: SecureRandom.hex(24))
      match.players.create!(name: "Alice")
      match.players.create!(name: "Bob")
      match
    end

    def finished_match
      match, = started_guest_match
      match.update!(finished_at: Time.current)
      match
    end

    def three_player_match
      match, = started_guest_match
      match.players.create!(name: "Cara")
      match
    end
end
