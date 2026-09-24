require "test_helper"

class PushSubscriptionTest < ActiveSupport::TestCase
  test "validates secure endpoints and stores a stable digest" do
    user = create_user("push-model-#{SecureRandom.hex(4)}@example.com")
    subscription = user.push_subscriptions.create!(
      endpoint: "https://push.example.test/subscriptions/abc",
      p256dh: "public-key",
      auth: "auth-secret",
      device_label: "Test browser"
    )

    assert_equal Digest::SHA256.hexdigest(subscription.endpoint), subscription.endpoint_digest
    assert_not_equal subscription.endpoint, subscription.ciphertext_for(:endpoint)
    assert_not_equal subscription.p256dh, subscription.ciphertext_for(:p256dh)
    assert_not_equal subscription.auth, subscription.ciphertext_for(:auth)

    duplicate = user.push_subscriptions.new(
      endpoint: subscription.endpoint,
      p256dh: "another-key",
      auth: "another-secret",
      device_label: "Duplicate"
    )
    assert_not duplicate.valid?
    assert_includes duplicate.errors[:endpoint_digest], "has already been taken"
  end

  test "rejects insecure or credential-bearing endpoints" do
    user = create_user("push-invalid-#{SecureRandom.hex(4)}@example.com")

    [ "http://push.example.test/a", "https://user:pass@push.example.test/a", "not a URI" ].each do |endpoint|
      subscription = user.push_subscriptions.new(endpoint:, p256dh: "key", auth: "secret", device_label: "Browser")
      assert_not subscription.valid?, endpoint
      assert subscription.errors[:endpoint].any?, endpoint
    end
  end
end
