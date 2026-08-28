require "test_helper"
require "ostruct"

class StripeWebhooksControllerTest < ActionDispatch::IntegrationTest
  test "checkout completed syncs user subscription" do
    user = create_user("webhook-checkout@example.com")
    subscription = subscription_fixture(id: "sub_test")
    event = OpenStruct.new(
      type: "checkout.session.completed",
      data: OpenStruct.new(
        object: OpenStruct.new(
          client_reference_id: user.id,
          customer: "cus_test",
          subscription: "sub_test",
          metadata: OpenStruct.new(tier: "premium", currency: "usd")
        )
      )
    )

    StripeBilling::Configuration.stubs(:webhook_secret).returns("whsec_test")
    Stripe::Webhook.stubs(:construct_event).returns(event)
    Stripe::Subscription.stubs(:retrieve).returns(subscription)

    post_webhook

    assert_response :success
    user.reload
    assert_equal "premium", user.account_tier
    assert_equal "cus_test", user.stripe_customer_id
    assert_equal "sub_test", user.stripe_subscription_id
    assert_equal "active", user.stripe_subscription_status
    assert user.premium_access?
  end

  test "subscription created resolves its user from Stripe metadata" do
    user = create_user("webhook-subscription@example.com")
    subscription = subscription_fixture(id: "sub_created", user_id: user.id)
    event = OpenStruct.new(type: "customer.subscription.created", data: OpenStruct.new(object: subscription))

    StripeBilling::Configuration.stubs(:webhook_secret).returns("whsec_test")
    Stripe::Webhook.stubs(:construct_event).returns(event)

    post_webhook

    assert_response :success
    user.reload
    assert_equal "sub_created", user.stripe_subscription_id
    assert_equal "premium", user.account_tier
  end

  test "expired subscriptions without an end date revoke access" do
    user = create_user("webhook-expired@example.com")
    user.update!(account_tier: "premium", stripe_subscription_id: "sub_expired")
    subscription = subscription_fixture(id: "sub_expired", status: "incomplete_expired", period_end: nil)
    event = OpenStruct.new(type: "customer.subscription.updated", data: OpenStruct.new(object: subscription))

    StripeBilling::Configuration.stubs(:webhook_secret).returns("whsec_test")
    Stripe::Webhook.stubs(:construct_event).returns(event)

    post_webhook

    assert_response :success
    assert_equal "free", user.reload.account_tier
  end

  test "unsigned webhooks are rejected when no signing secret is configured" do
    StripeBilling::Configuration.stubs(:webhook_secret).returns(nil)

    post_webhook

    assert_response :bad_request
  end

  private

  def post_webhook
    post "/stripe/webhooks", params: "{}", headers: { "CONTENT_TYPE" => "application/json", "HTTP_STRIPE_SIGNATURE" => "test-signature" }
  end

  def subscription_fixture(id:, user_id: nil, status: "active", period_end: 1.month.from_now.to_i)
    OpenStruct.new(
      id: id,
      customer: "cus_test",
      status: status,
      current_period_end: period_end,
      metadata: OpenStruct.new(user_id: user_id, tier: "premium", currency: "usd"),
      items: OpenStruct.new(data: [ OpenStruct.new(price: OpenStruct.new(id: "price_test", currency: "usd")) ])
    )
  end
end
