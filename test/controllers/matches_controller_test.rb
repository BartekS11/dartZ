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

  test "should show match" do
    match = Match.create!
    match.players.create!(name: "You", user: @user)
    match.players.create!(name: "Guest")

    get match_path(match)

    assert_response :success
  end
end
