require "test_helper"

class TrainingRecommendationsTest < ActiveSupport::TestCase
  test "does not recommend a focus before ten completed sessions with comparison data" do
    stats = [ stat("around_the_clock", completed_count: 9, trend: "declined", delta: 1.2) ]

    result = TrainingRecommendations.new(user: create_user("recommendation-small@example.com"), stats: stats).call

    assert_equal :insufficient_data, result[:status]
    assert_empty result[:recommendations]
  end

  test "recommends up to two modes with declining recent averages and gives evidence" do
    stats = [
      stat("around_the_clock", completed_count: 12, trend: "declined", delta: 2.0),
      stat("checkout_randomizer", completed_count: 10, trend: "declined", delta: 1.0),
      stat("around_the_clock_doubles", completed_count: 10, trend: "improved", delta: -1.0)
    ]

    result = TrainingRecommendations.new(user: create_user("recommendation-data@example.com"), stats: stats).call

    assert_equal :recommendations, result[:status]
    assert_equal %w[around_the_clock checkout_randomizer], result[:recommendations].map { |item| item[:mode] }
    assert_equal 12, result[:recommendations].first[:sample_size]
    assert_equal :recent_average_increased, result[:recommendations].first[:reason]
  end

  test "reports on track when comparable modes do not show a decline" do
    stats = [ stat("around_the_clock", completed_count: 10, trend: "improved", delta: -0.5) ]

    result = TrainingRecommendations.new(user: create_user("recommendation-track@example.com"), stats: stats).call

    assert_equal :on_track, result[:status]
    assert_empty result[:recommendations]
  end

  private

  def stat(mode, completed_count:, trend:, delta:)
    { mode: mode, completed_count: completed_count, trend: trend, delta: delta }
  end
end
