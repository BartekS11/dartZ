require "test_helper"

class AdvancedStatsControllerTest < ActionDispatch::IntegrationTest
  setup do
    FeatureAccess.stubs(:enabled?).returns(false)
  end

  test "requires authentication before disclosing feature state" do
    FeatureAccess.stubs(:enabled?).with(:advanced_stats).returns(false)

    get advanced_stats_path

    assert_redirected_to new_session_path
  end

  test "returns not found while feature is disabled" do
    user = premium_user("advanced-disabled@example.com")
    login_as(user)
    FeatureAccess.stubs(:enabled?).with(:advanced_stats).returns(false)

    get advanced_stats_path

    assert_response :not_found
  end

  test "returns forbidden to a free user when feature is enabled" do
    user = create_user("advanced-free@example.com")
    login_as(user)
    enable_advanced_stats

    get advanced_stats_path

    assert_response :forbidden
  end

  test "renders advanced metrics and accessible tables for premium users" do
    user = premium_user("advanced-premium@example.com")
    create_scored_match(user)
    login_as(user)
    enable_advanced_stats

    get advanced_stats_path

    assert_response :success
    assert_select "h1", I18n.t("stats.advanced.title")
    assert_select "[aria-label='#{I18n.t("stats.advanced.summary")}']"
    assert_select "table caption", I18n.t("stats.advanced.distribution_table")
    assert_select "th[scope='col']"
  end

  test "rejects malformed and reversed date filters without evaluating stats" do
    user = premium_user("advanced-invalid-date@example.com")
    login_as(user)
    enable_advanced_stats
    AdvancedMatchStats.expects(:new).never

    get advanced_stats_path, params: { from: "2026-09-10", to: "2026-01-01" }

    assert_redirected_to advanced_stats_path
    assert_equal "from must be on or before to", flash[:alert]
  end

  private

  def enable_advanced_stats
    FeatureAccess.stubs(:enabled?).with(:advanced_stats).returns(true)
  end

  def premium_user(email)
    create_user(email).tap { |user| user.update!(account_tier: "premium") }
  end

  def create_scored_match(user)
    match = Match.create!(starting_score: 301)
    player = match.players.create!(name: "Stats Player", user: user)
    match.players.create!(name: "Opponent")
    match_set = match.match_sets.create!
    leg = match_set.legs.create!(match: match)
    turn = leg.turns.create!(player: player, completed_at: Time.current, total_score: 60)
    3.times { turn.throws.create!(segment: 20, multiplier: :single) }
  end
end
