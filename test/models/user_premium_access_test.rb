require "test_helper"

class UserPremiumAccessTest < ActiveSupport::TestCase
  test "free users do not have premium access" do
    user = create_user("free@example.com")

    assert_not user.premium_access?
  end

  test "premium users have premium access" do
    user = create_user("premium@example.com")
    user.update!(account_tier: "premium")

    assert user.premium_access?
  end

  test "expired premium users do not have premium access" do
    user = create_user("expired@example.com")
    user.update!(account_tier: "premium", premium_access_expires_at: 1.day.ago)

    assert_not user.premium_access?
  end
end
