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

  test "active subscription is not expired" do
    user = create_user("active-subscription@example.com")
    user.update!(account_tier: "premium", stripe_subscription_id: "sub_1", stripe_subscription_status: "active", premium_access_expires_at: 1.month.from_now)

    assert user.subscribed?
    assert_not user.subscription_expired?
    assert user.premium_access?
  end

  test "subscription expired method is derived from access expiry" do
    user = create_user("expired-subscription@example.com")
    user.update!(account_tier: "pro", stripe_subscription_id: "sub_2", stripe_subscription_status: "canceled", premium_access_expires_at: 1.minute.ago)

    assert user.subscription_expired?
    assert_not user.premium_access?
  end
end
