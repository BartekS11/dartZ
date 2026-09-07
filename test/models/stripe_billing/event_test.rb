require "test_helper"
require "ostruct"

class StripeBilling::EventTest < ActiveSupport::TestCase
  test "invoice resolves expanded subscription and customer IDs" do
    user = create_user("invoice-event@example.com")
    user.update!(stripe_customer_id: "cus_event")
    subscription = subscription_fixture(customer: OpenStruct.new(id: "cus_event"))
    Stripe::Subscription.expects(:retrieve).with("sub_event").returns(subscription)

    process("invoice.paid", OpenStruct.new(subscription: OpenStruct.new(id: "sub_event")))

    assert_equal "premium", user.reload.account_tier
    assert_equal "sub_event", user.stripe_subscription_id
  end

  test "invoice without a subscription does not call Stripe" do
    Stripe::Subscription.expects(:retrieve).never

    process("invoice.payment_failed", OpenStruct.new(subscription: nil))
  end

  test "checkout metadata supplies missing subscription tier and currency" do
    user = create_user("checkout-event@example.com")
    subscription = subscription_fixture(metadata: OpenStruct.new, items: OpenStruct.new(data: []))
    Stripe::Subscription.expects(:retrieve).with("sub_event").returns(subscription)

    process("checkout.session.completed", OpenStruct.new(
      client_reference_id: nil,
      customer: OpenStruct.new(id: "cus_event"),
      subscription: OpenStruct.new(id: "sub_event"),
      metadata: OpenStruct.new(user_id: user.id, tier: "pro", currency: "pln")
    ))

    assert_equal "pro", user.reload.account_tier
    assert_equal "pln", user.subscription_currency
    assert_equal "cus_event", user.stripe_customer_id
  end

  test "price configuration supplies a missing tier" do
    user = create_user("price-event@example.com")
    user.update!(stripe_subscription_id: "sub_event")
    StripeBilling::Configuration.stubs(:price_id_for).returns(nil)
    StripeBilling::Configuration.stubs(:price_id_for).with(tier: "pro", currency: "usd").returns("price_event")

    process("customer.subscription.updated", subscription_fixture(metadata: OpenStruct.new))

    assert_equal "pro", user.reload.account_tier
  end

  test "cancellation retains access until the paid period ends" do
    user = create_user("canceled-event@example.com")
    user.update!(stripe_subscription_id: "sub_event")

    process("customer.subscription.deleted", subscription_fixture(status: "canceled"))
    assert user.reload.premium_access?

    process("customer.subscription.deleted", subscription_fixture(status: "canceled", current_period_end: 1.minute.ago.to_i))
    assert_equal "free", user.reload.account_tier
  end

  test "unknown events are logged without subscription lookups" do
    Stripe::Subscription.expects(:retrieve).never
    Rails.logger.expects(:info).with("Unhandled Stripe webhook event: unknown.event")

    process("unknown.event", nil)
  end

  private
    def process(type, object)
      StripeBilling::Event.new(OpenStruct.new(type: type, data: OpenStruct.new(object: object))).process
    end

    def subscription_fixture(**attributes)
      OpenStruct.new({
        id: "sub_event",
        customer: "cus_event",
        status: "active",
        current_period_end: 1.month.from_now.to_i,
        metadata: OpenStruct.new(tier: "premium", currency: "usd"),
        items: OpenStruct.new(data: [ OpenStruct.new(price: OpenStruct.new(id: "price_event", currency: "usd")) ])
      }.merge(attributes))
    end
end
