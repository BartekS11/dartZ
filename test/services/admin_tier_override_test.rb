require "test_helper"

class AdminTierOverrideTest < ActiveSupport::TestCase
  setup do
    @admin = AdminUser.create!(email_address: "tiers@example.com", password: "a-secure-password-123")
    @user = create_user("tier-user@example.com")
  end

  test "upgrade creates an indefinite override without changing Stripe state" do
    @user.update!(stripe_subscription_id: "sub_1", stripe_subscription_status: "active")

    AdminTierOverride.call(user: @user, admin_user: @admin, override: "pro")

    assert_equal "free", @user.reload.account_tier
    assert_equal "pro", @user.manual_tier_override
    assert_equal "pro", @user.effective_account_tier
    assert @user.premium_access?
    assert_equal "sub_1", @user.stripe_subscription_id
    assert_equal 1, @user.admin_tier_changes.count
  end

  test "downgrade requires a reason and rolls back" do
    @user.update!(manual_tier_override: "pro")

    assert_raises(AdminTierOverride::ReasonRequired) do
      AdminTierOverride.call(user: @user, admin_user: @admin, override: "free")
    end

    assert_equal "pro", @user.reload.manual_tier_override
    assert_empty @user.admin_tier_changes
  end

  test "downgrade with reason records the comment" do
    @user.update!(manual_tier_override: "pro")

    AdminTierOverride.call(user: @user, admin_user: @admin, override: "premium", reason: "Support adjustment")

    change = @user.admin_tier_changes.last
    assert_equal "Support adjustment", change.reason
    assert_equal "pro", change.previous_effective_tier
    assert_equal "premium", change.new_effective_tier
  end

  test "clearing an override restores managed tier and requires reason if lower" do
    @user.update!(account_tier: "premium", manual_tier_override: "pro")

    assert_raises(AdminTierOverride::ReasonRequired) do
      AdminTierOverride.call(user: @user, admin_user: @admin, override: "")
    end

    AdminTierOverride.call(user: @user, admin_user: @admin, override: "", reason: "Restore billing tier")
    assert_nil @user.reload.manual_tier_override
    assert_equal "premium", @user.effective_account_tier
  end

  test "manual free denies paid access and Stripe sync preserves the override" do
    @user.update!(manual_tier_override: "free")
    @user.sync_subscription!(tier: "pro", status: "active", current_period_end: 1.month.from_now)

    assert_equal "pro", @user.account_tier
    assert_equal "free", @user.effective_account_tier
    assert_not @user.premium_access?
  end

  test "rolls back the override when audit creation fails" do
    AdminTierChange.stubs(:create!).raises(ActiveRecord::RecordInvalid)

    assert_raises(ActiveRecord::RecordInvalid) do
      AdminTierOverride.call(user: @user, admin_user: @admin, override: "premium")
    end

    assert_nil @user.reload.manual_tier_override
  end

  test "rejects no-op changes" do
    assert_raises(AdminTierOverride::NoChange) do
      AdminTierOverride.call(user: @user, admin_user: @admin, override: nil)
    end
  end
end
