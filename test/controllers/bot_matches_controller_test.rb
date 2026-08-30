require "test_helper"

class BotMatchesControllerTest < ActionDispatch::IntegrationTest
  test "creates bot match with selected difficulty" do
    user = create_user("bot-level@example.com")
    login_as(user)

    post bot_match_path, params: {
      player_name: "Human",
      bot_name: "Practice Bot",
      bot_level: "12",
      starting_score: "501",
      best_of_legs: "1",
      best_of_sets: "1",
      double_out: "1"
    }

    assert_redirected_to match_path(Match.last)
    bot = Match.last.players.find_by!(bot: true)
    assert_equal 10, bot.bot_level
  end
end
