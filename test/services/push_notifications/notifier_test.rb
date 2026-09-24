require "test_helper"

class PushNotifications::NotifierTest < ActiveSupport::TestCase
  setup do
    @sender = create_user("push-notifier-sender-#{SecureRandom.hex(4)}@example.com")
    @recipient = create_user("push-notifier-recipient-#{SecureRandom.hex(4)}@example.com")
    @sender.update!(nickname: "Alice")
    @recipient.update!(locale: "pl")
    @subscription = @recipient.push_subscriptions.create!(
      endpoint: "https://push.example.test/subscriptions/#{SecureRandom.hex(8)}",
      p256dh: "public-key",
      auth: "auth-secret",
      device_label: "Test browser"
    )
    FeatureAccess.stubs(:enabled?).with(:web_push).returns(true)
  end

  test "uses recipient locale and deduplicates the same event" do
    request_record = FriendRequest.create!(requester: @sender, recipient: @recipient)
    PushNotifications::Notifier.friend_request(request_record)
    delivery = @subscription.push_deliveries.find_by!(category: "friend_requests")

    assert_equal "Nowe zaproszenie do znajomych", delivery.payload.fetch("title")
    assert_includes delivery.payload.fetch("body"), "Alice"

    PushNotifications::Notifier.friend_request(request_record)
    assert_equal 1, @subscription.push_deliveries.where(category: "friend_requests").count
  end

  test "uses a localized generic actor label instead of an email address" do
    @sender.update!(nickname: nil)
    request_record = FriendRequest.create!(requester: @sender, recipient: @recipient)

    PushNotifications::Notifier.friend_request(request_record)
    body = @subscription.push_deliveries.find_by!(category: "friend_requests").payload.fetch("body")

    assert_includes body, "Gracz DartZ"
    assert_not_includes body, @sender.email_address
  end

  test "honors category opt out" do
    @recipient.create_notification_preference!(friend_requests: false)

    request_record = FriendRequest.create!(requester: @sender, recipient: @recipient)
    PushNotifications::Notifier.friend_request(request_record)

    assert_empty @subscription.push_deliveries
  end
end
