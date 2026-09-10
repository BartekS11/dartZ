require "test_helper"

class AdminTierChangeTest < ActiveSupport::TestCase
  setup do
    @admin = AdminUser.create!(email_address: "audit@example.com", password: "a-secure-password-123")
    @user = create_user("audit-user@example.com")
    @change = AdminTierOverride.call(user: @user, admin_user: @admin, override: "premium")
      .admin_tier_changes.last
  end

  test "audit records cannot be updated or destroyed" do
    assert_not @change.update(reason: "rewritten")
    assert_not @change.destroy
    assert AdminTierChange.exists?(@change.id)
  end
end
