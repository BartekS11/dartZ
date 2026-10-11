require "test_helper"

class AccountTierCatalogTest < ActiveSupport::TestCase
  setup do
    I18n.locale = :en
    @catalog = -> { AccountTierCatalog.new(prices: { free: "$0", premium: "$4.99", pro: "$9.99" }).tiers.index_by { |tier| tier[:key] } }
  end

  test "billing features reflect implemented Free Premium and Pro access" do
    FeatureAccess.stubs(:enabled?).returns(false)
    tiers = @catalog.call

    assert_includes tiers.fetch("free")[:features], "Invite friends to remote matches"
    assert_includes tiers.fetch("free")[:features], "Anonymous, revocable match-result links"
    assert_includes tiers.fetch("free")[:features], "Basic insights from saved training history"
    assert_includes tiers.fetch("premium")[:features], "Detailed leg-by-leg reviews and checkout performance"
    assert_includes tiers.fetch("premium")[:features], "Template, custom, and stats-generated practice plans"
    assert_includes tiers.fetch("pro")[:features], "Evidence-based training recommendations"
    assert_includes tiers.fetch("pro")[:features], "Pro per-match scoring and checkout analysis"
    assert_not tiers.fetch("pro")[:features].any? { |feature| feature.match?(/future|priority|league/i) }
  end

  test "rollout-controlled features are shown only when enabled" do
    FeatureAccess.stubs(:enabled?).returns(false)
    FeatureAccess.stubs(:enabled?).with(:friends).returns(true)
    FeatureAccess.stubs(:enabled?).with(:expanded_training).returns(true)
    FeatureAccess.stubs(:enabled?).with(:advanced_stats).returns(true)

    tiers = @catalog.call

    assert_includes tiers.fetch("free")[:features], "Friends and match challenges"
    assert_includes tiers.fetch("premium")[:features], "Expanded training modes"
    assert_includes tiers.fetch("premium")[:features], "Advanced match statistics and filters"
  end
end
