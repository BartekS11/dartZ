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

    assert_redirected_to match_path(Match.last)
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
  end
end
