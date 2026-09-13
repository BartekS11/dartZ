require "test_helper"

class FeatureAccessTest < ActiveSupport::TestCase
  test "defines every roadmap feature and keeps configuration boolean" do
    expected = %i[advanced_stats expanded_training friends web_push offline_scoring]

    assert_equal expected, FeatureAccess::DEFINITIONS.keys
    assert_equal expected, Rails.configuration.x.roadmap_features.keys
    assert Rails.configuration.x.roadmap_features.values.all? { |value| value == true || value == false }
  end

  test "premium features require active premium access" do
    free_user = create_user("feature-free@example.com")
    premium_user = create_user("feature-premium@example.com")
    premium_user.update!(account_tier: "premium")
    expired_user = create_user("feature-expired@example.com")
    expired_user.update!(account_tier: "premium", premium_access_expires_at: 1.day.ago)

    assert_not FeatureAccess.entitled?(:advanced_stats, user: nil)
    assert_not FeatureAccess.entitled?(:advanced_stats, user: free_user)
    assert FeatureAccess.entitled?(:advanced_stats, user: premium_user)
    assert_not FeatureAccess.entitled?(:advanced_stats, user: expired_user)
    assert FeatureAccess.entitled?(:offline_scoring, user: premium_user)
  end

  test "free roadmap features still require a registered user" do
    free_user = create_user("feature-friends@example.com")

    assert_not FeatureAccess.entitled?(:friends, user: nil)
    assert FeatureAccess.entitled?(:friends, user: free_user)
    assert FeatureAccess.entitled?(:web_push, user: free_user)
  end

  test "unknown features fail closed" do
    assert_raises(KeyError) { FeatureAccess.enabled?(:unknown) }
    assert_raises(KeyError) { FeatureAccess.entitled?(:unknown, user: nil) }
  end
end
