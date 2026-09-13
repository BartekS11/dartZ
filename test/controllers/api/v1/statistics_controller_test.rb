require "test_helper"

class Api::V1::StatisticsControllerTest < ActionDispatch::IntegrationTest
  test "requires the feature flag after preserving bearer authentication" do
    user = create_user("api-stats-disabled@example.com")
    FeatureAccess.stubs(:enabled?).with(:advanced_stats).returns(false)

    get "/api/v1/statistics/summary", headers: bearer(user)

    assert_response :not_found
    assert_equal "feature_unavailable", response.parsed_body.dig("error", "code")
  end

  test "returns forbidden to an authenticated free user" do
    user = create_user("api-stats-free@example.com")
    enable_advanced_stats

    get "/api/v1/statistics/summary", headers: bearer(user)

    assert_response :forbidden
    assert_equal "feature_forbidden", response.parsed_body.dig("error", "code")
  end

  test "returns advanced summary and data coverage to a premium user" do
    user = premium_user("api-stats-premium@example.com")
    create_scored_match(user)
    enable_advanced_stats

    get "/api/v1/statistics/summary", headers: bearer(user)

    assert_response :success
    data = response.parsed_body.fetch("data")
    assert_equal 1, data.fetch("matches_played")
    assert_equal 60.0, data.fetch("three_dart_average")
    assert_equal 100.0, data.dig("coverage", "detailed_percentage")
  end

  test "paginates collection endpoints with the roadmap envelope" do
    user = premium_user("api-stats-pagination@example.com")
    create_scored_match(user)
    enable_advanced_stats

    get "/api/v1/statistics/distribution", params: { page: 2, per_page: 3 }, headers: bearer(user)

    assert_response :success
    assert_equal 3, response.parsed_body.fetch("data").size
    assert_equal({
      "page" => 2,
      "per_page" => 3,
      "total_count" => 8,
      "total_pages" => 3
    }, response.parsed_body.fetch("pagination"))
  end

  test "returns structured validation errors for malformed date filters" do
    user = premium_user("api-stats-date@example.com")
    enable_advanced_stats

    get "/api/v1/statistics/trends", params: { from: "10/09/2026" }, headers: bearer(user)

    assert_response :unprocessable_entity
    assert_equal "invalid_parameter", response.parsed_body.dig("error", "code")
    assert_equal "from", response.parsed_body.dig("error", "details", "parameter")
  end

  test "guest tokens cannot access premium statistics" do
    enable_advanced_stats
    post "/api/v1/auth/guest"
    token = response.parsed_body.fetch("token")

    get "/api/v1/statistics/checkouts", headers: { "Authorization" => "Bearer #{token}" }

    assert_response :forbidden
  end

  private

  def enable_advanced_stats
    FeatureAccess.stubs(:enabled?).with(:advanced_stats).returns(true)
  end

  def bearer(user)
    { "Authorization" => "Bearer #{JsonWebToken.encode(user_id: user.id)}" }
  end

  def premium_user(email)
    create_user(email).tap { |user| user.update!(account_tier: "premium") }
  end

  def create_scored_match(user)
    match = Match.create!(starting_score: 301)
    player = match.players.create!(name: "API Stats", user: user)
    match.players.create!(name: "Opponent")
    match_set = match.match_sets.create!
    leg = match_set.legs.create!(match: match)
    turn = leg.turns.create!(player: player, completed_at: Time.current, total_score: 60)
    3.times { turn.throws.create!(segment: 20, multiplier: :single) }
  end
end
