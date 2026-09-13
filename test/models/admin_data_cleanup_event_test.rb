require "test_helper"

class AdminDataCleanupEventTest < ActiveSupport::TestCase
  test "audit events cannot be updated or destroyed" do
    admin = AdminUser.create!(email_address: "immutable-cleanup@example.com", password: "a-secure-password-123")
    user = create_user("immutable-cleanup-user@example.com")
    cleanup = user.admin_data_cleanups.create!(categories: %w[matches], counts: { "matches" => 1 }, status: "cleared", cleared_at: Time.current)
    event = cleanup.events.create!(admin_user: admin, user: user, action: "clear", categories: cleanup.categories, counts: cleanup.counts, reason: "Requested")

    assert_not event.update(reason: "Changed")
    assert_not event.destroy
    assert AdminDataCleanupEvent.exists?(event.id)
  end
end
