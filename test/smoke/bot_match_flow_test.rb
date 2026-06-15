require "test_helper"

class BotMatchFlowTest < ActionDispatch::IntegrationTest
  setup do
    @user = User.create!(
      email_address: "smoke-bot@example.com",
      password: "password",
      password_confirmation: "password"
    )

    post session_path, params: {
      email_address: @user.email_address,
      password: "password"
    }
  end

  test "signed in user can create bot match" do
    assert_difference("Match.count", 1) do
      post bot_match_path, params: {
        player_name: "SmokeUser",
        bot_name: "RubyBot",
        bot_level: 10,
        best_of_legs: 3,
        best_of_sets: 1
      }
    end

    match = Match.order(:created_at).last

    assert_redirected_to match_path(match)
    assert_equal 2, match.players.count
    assert_equal true, match.players.exists?(bot: true, name: "RubyBot")
    assert_equal "SmokeUser", @user.reload.nickname
    assert_not_nil match.current_leg
    assert_not_nil match.match_identifier
  end
end
