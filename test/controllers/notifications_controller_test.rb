require "test_helper"

class NotificationsControllerTest < ActionDispatch::IntegrationTest
  setup do
    @user = create_user("push-html-#{SecureRandom.hex(4)}@example.com")
    login_as(@user)
    FeatureAccess.stubs(:enabled?).returns(false)
    FeatureAccess.stubs(:enabled?).with(:web_push).returns(true)
  end

  test "shows opt in controls without exposing private subscription data" do
    subscription = @user.push_subscriptions.create!(
      endpoint: "https://push.example.test/subscriptions/#{SecureRandom.hex(8)}",
      p256dh: "private-browser-key",
      auth: "private-auth-secret",
      device_label: "My browser"
    )

    get notifications_path

    assert_response :success
    assert_includes response.body, "My browser"
    assert_not_includes response.body, subscription.endpoint
    assert_not_includes response.body, subscription.p256dh
    assert_not_includes response.body, subscription.auth
  end

  test "updates preferences and revokes only the current user's device" do
    subscription = @user.push_subscriptions.create!(
      endpoint: "https://push.example.test/subscriptions/#{SecureRandom.hex(8)}",
      p256dh: "key",
      auth: "secret",
      device_label: "My browser"
    )

    patch notifications_path, params: {
      notification_preference: {
        friend_requests: "0",
        friendship_acceptance: "1",
        match_challenges: "1",
        tournament_round_ready: "0"
      }
    }
    assert_redirected_to notifications_path
    assert_equal false, @user.reload.notification_preference.friend_requests
    assert_equal false, @user.notification_preference.tournament_round_ready

    delete push_subscription_path(subscription)
    assert_redirected_to notifications_path
    assert subscription.reload.revoked_at
  end
end
