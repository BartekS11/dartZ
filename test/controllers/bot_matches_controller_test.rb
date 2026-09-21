require "test_helper"

class BotMatchesControllerTest < ActionDispatch::IntegrationTest
  test "new shows free user allowance" do
    user = create_user("bot-allowance-page@example.com")
    login_as(user)

    get new_bot_match_path

    assert_response :success
    assert_select ".theme-chip", text: /40 of 40/
  end

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

  test "free user can create bot match within allowance" do
    user = create_user("bot-free-within@example.com")
    login_as(user)

    assert_difference -> { Match.count }, 1 do
      post bot_match_path, params: bot_match_params(best_of_legs: "5")
    end

    assert_redirected_to match_path(Match.last)
  end

  test "free user cannot create bot match over allowance" do
    user = create_user("bot-free-over@example.com")
    40.times { create_bot_match!(user, best_of_legs: 5, created_at: 1.day.ago) }
    login_as(user)

    assert_no_difference -> { Match.count } do
      post bot_match_path, params: bot_match_params(best_of_legs: "1")
    end

    assert_redirected_to new_bot_match_path
    follow_redirect!
    assert_match I18n.t("bot_matches.limit_exceeded", remaining: 0), response.body
  end

  test "free user is blocked when proposed Bo10 costs more than remaining allowance" do
    user = create_user("bot-free-bo10-over@example.com")
    39.times { create_bot_match!(user, best_of_legs: 5, created_at: 1.day.ago) }
    login_as(user)

    assert_no_difference -> { Match.count } do
      post bot_match_path, params: bot_match_params(best_of_legs: "10")
    end

    assert_redirected_to new_bot_match_path
  end

  test "premium user can create bot match over free allowance" do
    user = create_user("bot-premium-unlimited@example.com")
    user.update!(account_tier: "premium")
    40.times { create_bot_match!(user, best_of_legs: 5, created_at: 1.day.ago) }
    login_as(user)

    assert_difference -> { Match.count }, 1 do
      post bot_match_path, params: bot_match_params(best_of_legs: "10")
    end

    assert_redirected_to match_path(Match.last)
  end

  private

  def bot_match_params(best_of_legs: "1")
    {
      player_name: "Human",
      bot_name: "Practice Bot",
      bot_level: "12",
      starting_score: "501",
      best_of_legs: best_of_legs,
      best_of_sets: "1",
      double_out: "1"
    }
  end

  def create_bot_match!(user, best_of_legs:, created_at: Time.current)
    match = MatchCreator.call(
      settings: MatchSettings.new(
        best_of_legs: best_of_legs,
        best_of_sets: 1,
        starting_score: 501,
        double_in: false,
        double_out: true
      ),
      players: [
        { name: "Human", user: user },
        { name: "Bot", bot: true, bot_level: 5 }
      ]
    )
    match.update_column(:created_at, created_at)
    match
  end
end
