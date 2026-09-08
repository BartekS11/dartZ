require "test_helper"

class MatchesControllerTest < ActionDispatch::IntegrationTest
  setup do
    @user = User.create!(
      email_address: "test@example.com",
      password: "password"
    )

    # simulate login
    post session_path, params: {
      email_address: @user.email_address,
      password: "password"
    }
  end

  test "should get index" do
    get matches_path
    assert_response :success
  end

  test "should create match" do
    assert_difference("Match.count", 1) do
      post matches_path
    end

    match = Match.last
    assert_redirected_to match_path(match)
    assert_includes @response.redirect_url, match.public_id
    assert_not_includes @response.redirect_url, "/matches/#{match.id}"
  end

  test "premium user match player stores dart setup snapshot" do
    @user.update!(account_tier: "premium")
    setup = @user.create_dart_setup!(
      manufacturer: "target",
      weight_g: 24.0,
      shaft_type: "carbon",
      shaft_length_mm: 42,
      point_length_mm: 35
    )

    post matches_path, params: { player1_name: "Premium Player" }

    player = Match.last.players.find_by!(user: @user)
    assert_equal setup, player.dart_setup
    assert_equal setup.fingerprint, player.dart_setup_fingerprint
    assert_equal "Target", player.dart_setup_snapshot["manufacturer_label"]
  end

  test "should show match" do
    match = Match.create!
    match.players.create!(name: "You", user: @user)
    match.players.create!(name: "Guest")
    match.start_first_set!

    get match_path(match)

    assert_response :success
    assert_select "#voice-announcements", count: 1
  end

  test "numeric match URL returns 404" do
    match = Match.create!
    match.players.create!(name: "You", user: @user)

    get "/matches/#{match.id}"

    assert_response :not_found
  end

  test "invite lobby can let invited player start" do
    post matches_path, params: { invite_match: "1", player1_name: "Alice" }
    match = Match.last

    assert_equal 1, match.starting_player_position

    patch match_invite_starter_path(match), params: { invite_starter: "invitee" }
    assert_redirected_to match_invite_path(match)
    assert_equal 2, match.reload.starting_player_position

    delete session_path
    post accept_match_invite_path(match.invite_token), params: { player_name: "Bob" }

    match.reload
    bob = match.players.find_by!(name: "Bob")
    assert_equal bob, match.current_leg.current_turn.player
  end

  test "guest immediate match is not marked as remote invite locked" do
    delete session_path

    post matches_path, params: { player1_name: "Guest 1", player2_name: "Guest 2" }
    match = Match.last

    get match_path(match), params: { guest_token: match.guest_token }

    assert_response :success
    assert_select "#match-live[data-match-view-remote-invite-value='false']"
    assert_select "#voice-announcements", count: 0
    assert_no_match(/data-match-view-my-player-id-value="\d+"/, response.body)
  end
end
