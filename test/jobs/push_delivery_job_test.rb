require "test_helper"

class PushDeliveryJobTest < ActiveJob::TestCase
  setup do
    @user = create_user("push-job-#{SecureRandom.hex(4)}@example.com")
    @subscription = @user.push_subscriptions.create!(
      endpoint: "https://push.example.test/subscriptions/#{SecureRandom.hex(8)}",
      p256dh: "public-key",
      auth: "auth-secret",
      device_label: "Test browser"
    )
    @delivery = @subscription.push_deliveries.create!(
      category: "friend_requests",
      deduplication_key: "test:#{SecureRandom.uuid}",
      payload: { title: "Title", body: "Body", path: "/friends" }
    )
    @original_adapter = Rails.application.config.x.web_push.delivery_adapter
  end

  teardown do
    Rails.application.config.x.web_push.delivery_adapter = @original_adapter
  end

  test "uses injected adapter and records successful delivery" do
    adapter = mock("push adapter")
    adapter.expects(:deliver).with do |arguments|
      arguments[:subscription] == @subscription &&
        arguments.dig(:payload, :options, :data, :path) == "/friends"
    end
    Rails.application.config.x.web_push.delivery_adapter = adapter

    PushDeliveryJob.perform_now(@delivery.id)

    assert_equal "delivered", @delivery.reload.status
    assert @delivery.delivered_at
    assert @subscription.reload.last_success_at
  end

  test "revokes permanently invalid subscription without retry" do
    adapter = mock("push adapter")
    adapter.stubs(:deliver).raises(PushNotifications::PermanentDeliveryError.new("gone", code: "http_410"))
    Rails.application.config.x.web_push.delivery_adapter = adapter

    assert_no_enqueued_jobs { PushDeliveryJob.perform_now(@delivery.id) }

    assert_equal "failed", @delivery.reload.status
    assert_equal "http_410", @delivery.last_error_code
    assert @subscription.reload.revoked_at
  end

  test "bounds transient retries" do
    adapter = mock("push adapter")
    adapter.stubs(:deliver).raises(PushNotifications::TransientDeliveryError.new("timeout", code: "timeout"))
    Rails.application.config.x.web_push.delivery_adapter = adapter

    assert_enqueued_with(job: PushDeliveryJob) { PushDeliveryJob.perform_now(@delivery.id) }
    assert_equal "pending", @delivery.reload.status

    @delivery.update!(attempts: PushDeliveryJob::MAX_ATTEMPTS - 1)
    assert_no_enqueued_jobs { PushDeliveryJob.perform_now(@delivery.id) }
    assert_equal "failed", @delivery.reload.status
    assert_equal PushDeliveryJob::MAX_ATTEMPTS, @delivery.attempts
  end
end
