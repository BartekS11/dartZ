require "test_helper"

class AdminUserTest < ActiveSupport::TestCase
  test "requires a long password" do
    admin = AdminUser.new(email_address: "admin@example.com", password: "too-short")

    assert_not admin.valid?
    assert_includes admin.errors[:password], "is too short (minimum is 16 characters)"
  end

  test "normalizes email and creates expiring sessions" do
    admin = AdminUser.create!(email_address: "  ADMIN@Example.com ", password: "a-secure-password-123")
    session = admin.admin_sessions.create!(expires_at: 12.hours.from_now)

    assert_equal "admin@example.com", admin.email_address
    assert_not session.expired?
  end
end
