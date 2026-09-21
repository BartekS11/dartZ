require "test_helper"

class BotMatchAllowanceTest < ActiveSupport::TestCase
  test "free user starts with full allowance" do
    user = create_user("bot-allowance-empty@example.com")

    allowance = BotMatchAllowance.new(user)

    assert_equal 40, allowance.limit
    assert_equal 0, allowance.used
    assert_equal 40, allowance.remaining
    assert allowance.allowed?(best_of_legs: 5)
  end

  test "cost is one credit per started Bo5 chunk" do
    assert_equal 1, BotMatchAllowance.cost_for(best_of_legs: 1)
    assert_equal 1, BotMatchAllowance.cost_for(best_of_legs: 5)
    assert_equal 2, BotMatchAllowance.cost_for(best_of_legs: 7)
    assert_equal 2, BotMatchAllowance.cost_for(best_of_legs: 10)
    assert_equal 3, BotMatchAllowance.cost_for(best_of_legs: 11)
  end

  test "counts bot match credits from rolling seven day window" do
    user = create_user("bot-allowance-window@example.com")
    create_bot_match!(user, best_of_legs: 5, created_at: 6.days.ago)
    create_bot_match!(user, best_of_legs: 10, created_at: 2.days.ago)
    create_bot_match!(user, best_of_legs: 15, created_at: 8.days.ago)

    allowance = BotMatchAllowance.new(user)

    assert_equal 3, allowance.used
    assert_equal 37, allowance.remaining
  end

  test "free user is blocked when proposed match exceeds remaining credits" do
    user = create_user("bot-allowance-blocked@example.com")
    40.times { create_bot_match!(user, best_of_legs: 5, created_at: 1.day.ago) }

    allowance = BotMatchAllowance.new(user)

    assert_equal 40, allowance.used
    assert_equal 0, allowance.remaining
    refute allowance.allowed?(best_of_legs: 1)
  end

  test "premium user is unlimited" do
    user = create_user("bot-allowance-premium@example.com")
    user.update!(account_tier: "premium")
    45.times { create_bot_match!(user, best_of_legs: 5, created_at: 1.day.ago) }

    allowance = BotMatchAllowance.new(user)

    assert allowance.unlimited?
    assert_equal 0, allowance.used
    assert_nil allowance.remaining
    assert allowance.allowed?(best_of_legs: 99)
  end

  private

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
