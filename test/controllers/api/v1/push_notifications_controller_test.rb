require "test_helper"

class Api::V1::PushNotificationsControllerTest < ActionDispatch::IntegrationTest
  setup do
    @user = create_user("api-push-#{SecureRandom.hex(4)}@example.com")
    @headers = { "Authorization" => "Bearer #{JsonWebToken.encode(user_id: @user.id)}" }
    FeatureAccess.stubs(:enabled?).with(:web_push).returns(true)
  end

  test "creates and lists only public subscription metadata" do
    post "/api/v1/push/subscriptions", params: subscription_payload, headers: @headers, as: :json

    assert_response :created
    id = response.parsed_body.dig("data", "id")
    assert_match(/\Aps_/, id)
    assert_not_includes response.body, "push.example.test"
    assert_not_includes response.body, "p256dh"
    assert_not_includes response.body, "auth-secret"

    get "/api/v1/push/subscriptions", headers: @headers
    assert_response :success
    assert_equal id, response.parsed_body.dig("data", 0, "id")
    assert response.parsed_body.key?("pagination")

    delete "/api/v1/push/subscriptions/#{id}", headers: @headers
    assert_response :no_content
    assert @user.push_subscriptions.find_by!(public_id: id).revoked_at
  end

  test "reads and updates category preferences" do
    get "/api/v1/notification_preferences", headers: @headers
    assert_response :success
    assert_equal true, response.parsed_body.dig("data", "friend_requests")

    patch "/api/v1/notification_preferences", params: { friend_requests: false }, headers: @headers, as: :json
    assert_response :success
    assert_equal false, response.parsed_body.dig("data", "friend_requests")
  end

  test "queues a test notification and deduplicates event notifications" do
    create_subscription

    assert_enqueued_jobs 1 do
      post "/api/v1/push/test", headers: @headers, as: :json
    end
    assert_response :accepted

    request_record = FriendRequest.create!(requester: create_user("push-sender-#{SecureRandom.hex(4)}@example.com"), recipient: @user)
    PushNotifications::Notifier.friend_request(request_record)
    assert_equal 1, request_record.recipient.push_subscriptions.first.push_deliveries.where(category: "friend_requests").count
    PushNotifications::Notifier.friend_request(request_record)
    assert_equal 1, request_record.recipient.push_subscriptions.first.push_deliveries.where(category: "friend_requests").count
  end

  test "requires registered user and enabled feature" do
    get "/api/v1/push/subscriptions"
    assert_response :unauthorized

    guest = { "Authorization" => "Bearer #{JsonWebToken.encode(guest: true, guest_id: SecureRandom.uuid)}" }
    get "/api/v1/push/subscriptions", headers: guest
    assert_response :forbidden

    FeatureAccess.unstub(:enabled?)
    FeatureAccess.stubs(:enabled?).with(:web_push).returns(false)
    get "/api/v1/push/subscriptions", headers: @headers
    assert_response :not_found
  end

  private

  def create_subscription
    post "/api/v1/push/subscriptions", params: subscription_payload, headers: @headers, as: :json
    assert_response :created
  end

  def subscription_payload
    {
      endpoint: "https://push.example.test/subscriptions/#{SecureRandom.hex(8)}",
      device_label: "Test browser",
      keys: { p256dh: "public-key", auth: "auth-secret" }
    }
  end
end
