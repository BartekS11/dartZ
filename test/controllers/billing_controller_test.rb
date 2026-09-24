require "test_helper"
require "ostruct"

class BillingControllerTest < ActionDispatch::IntegrationTest
  test "requires login" do
    get billing_path

    assert_redirected_to new_session_path
  end

  test "logged in user can view tiers" do
    user = create_user("billing@example.com")
    login_as(user)

    get billing_path

    assert_response :success
    assert_select "h1", "Upgrade"
    assert_select "h2", "Free"
    assert_select "h2", "Premium"
    assert_select "h2", "Pro"
    assert_select "select[name='billing_interval']"
    assert_select "form[action='#{checkout_billing_path(tier: "premium", interval: "month")}']"
    assert_select "form[action='#{checkout_billing_path(tier: "pro", interval: "month")}']"
  end

  test "shows current account tier" do
    user = create_user("premium-billing@example.com")
    user.update!(account_tier: "premium")
    login_as(user)

    get billing_path

    assert_response :success
    assert_select ".theme-chip", text: /Current: Premium/
    assert_select ".theme-chip", text: "Current", count: 1
  end

  test "polish locale displays pln pricing" do
    user = create_user("pln-billing@example.com")
    login_as(user)

    get billing_path(locale: "pl")

    assert_response :success
    assert_includes response.body, "19,99 zł"
    assert_includes response.body, "PLN"
  end

  test "checkout rejects invalid tier" do
    user = create_user("bad-tier@example.com")
    login_as(user)

    post checkout_billing_path(tier: "free")

    assert_redirected_to billing_path
  end

  test "checkout redirects subscribed users to the customer portal" do
    user = create_user("subscribed-checkout@example.com")
    user.update!(account_tier: "premium", stripe_subscription_id: "sub_test", stripe_subscription_status: "active")
    login_as(user)

    original_key = Stripe.api_key
    Stripe.api_key = "stripe_secret_key_fake"
    Stripe::Checkout::Session.expects(:create).never

    post checkout_billing_path(tier: "pro", interval: "month")

    assert_redirected_to billing_path
    assert_equal "Manage your active subscription in the Stripe customer portal.", flash[:alert]
  ensure
    Stripe.api_key = original_key
  end

  test "checkout creates stripe session" do
    user = create_user("checkout@example.com")
    login_as(user)
    original_key = Stripe.api_key
    Stripe.api_key = "stripe_secret_key_fake"

    customer = OpenStruct.new(id: "cus_test")
    session = OpenStruct.new(url: "https://checkout.stripe.test/session")

    StripeBilling::Configuration.stubs(:price_id_for).returns("price_test")
    Stripe::Customer.stubs(:create).returns(customer)
    Stripe::Checkout::Session.stubs(:create).returns(session)

    post checkout_billing_path(tier: "premium", interval: "month")

    assert_redirected_to "https://checkout.stripe.test/session"
    assert_equal "cus_test", user.reload.stripe_customer_id
  ensure
    Stripe.api_key = original_key
  end

  test "annual checkout uses a computed yearly recurring price" do
    user = create_user("annual-checkout@example.com")
    login_as(user)
    original_key = Stripe.api_key
    Stripe.api_key = "stripe_secret_key_fake"
    Stripe::Customer.stubs(:create).returns(OpenStruct.new(id: "cus_annual"))
    Stripe::Checkout::Session.stubs(:create).with do |parameters|
      item = parameters[:line_items].first
      item[:price_data][:currency] == "usd" &&
        item[:price_data][:unit_amount] == 4_491 &&
        item[:price_data][:recurring][:interval] == "year" &&
        parameters[:subscription_data][:metadata][:interval] == "year"
    end.returns(OpenStruct.new(url: "https://checkout.stripe.test/annual"))

    post checkout_billing_path(tier: "premium", interval: "year")

    assert_redirected_to "https://checkout.stripe.test/annual"
  ensure
    Stripe.api_key = original_key
  end

  test "monthly subscriber can schedule yearly price at current period end" do
    user = create_user("switch-yearly@example.com")
    user.update!(account_tier: "premium", stripe_subscription_id: "sub_existing", stripe_subscription_status: "active")
    login_as(user)
    original_key = Stripe.api_key
    Stripe.api_key = "stripe_secret_key_fake"
    start_at = 1.month.ago.to_i
    end_at = 1.month.from_now.to_i
    item = OpenStruct.new(price: OpenStruct.new(id: "price_month", currency: "usd", product: "prod_premium", recurring: OpenStruct.new(interval: "month")), quantity: 1)
    subscription = OpenStruct.new(id: "sub_existing", current_period_start: start_at, current_period_end: end_at, items: OpenStruct.new(data: [ item ]))
    schedule = OpenStruct.new(id: "sched_new")
    Stripe::Subscription.stubs(:retrieve).with("sub_existing").returns(subscription)
    Stripe::Price.stubs(:create).with do |parameters|
      parameters[:unit_amount] == 4_491 && parameters[:recurring][:interval] == "year" && parameters[:product] == "prod_premium"
    end.returns(OpenStruct.new(id: "price_year"))
    Stripe::SubscriptionSchedule.stubs(:create).with(from_subscription: "sub_existing").returns(schedule)
    Stripe::SubscriptionSchedule.expects(:update).with do |schedule_id, parameters|
      schedule_id == "sched_new" &&
        parameters[:end_behavior] == "release" &&
        parameters[:phases][0][:start_date] == start_at &&
        parameters[:phases][0][:end_date] == end_at &&
        parameters[:phases][1][:start_date] == end_at &&
        parameters[:phases][1][:iterations] == 1 &&
        parameters[:phases][1][:items] == [ { price: "price_year", quantity: 1 } ] &&
        parameters[:phases][1][:proration_behavior] == "none"
    end

    post checkout_billing_path(tier: "premium", interval: "year")

    assert_redirected_to billing_path
    assert_equal "Your subscription will switch to yearly billing at the end of the current period.", flash[:notice]
  ensure
    Stripe.api_key = original_key
  end

  test "does not create a duplicate schedule when a subscription already has one" do
    user = create_user("scheduled-yearly@example.com")
    user.update!(account_tier: "premium", stripe_subscription_id: "sub_scheduled", stripe_subscription_status: "active")
    login_as(user)
    original_key = Stripe.api_key
    Stripe.api_key = "stripe_secret_key_fake"
    subscription = OpenStruct.new(schedule: "sched_existing")
    Stripe::Subscription.stubs(:retrieve).with("sub_scheduled").returns(subscription)
    Stripe::Price.expects(:create).never
    Stripe::SubscriptionSchedule.expects(:create).never

    post checkout_billing_path(tier: "premium", interval: "year")

    assert_redirected_to billing_path
    assert_equal "A billing change is already scheduled for your subscription.", flash[:notice]
  ensure
    Stripe.api_key = original_key
  end

  test "rejects unsupported billing interval" do
    user = create_user("bad-interval@example.com")
    login_as(user)

    post checkout_billing_path(tier: "premium", interval: "weekly")

    assert_redirected_to billing_path
    assert_equal "Choose a valid billing interval.", flash[:alert]
  end

  test "portal creates stripe portal session" do
    user = create_user("portal@example.com")
    user.update!(stripe_customer_id: "cus_test")
    login_as(user)
    original_key = Stripe.api_key
    Stripe.api_key = "stripe_secret_key_fake"

    session = OpenStruct.new(url: "https://billing.stripe.test/session")
    Stripe::BillingPortal::Session.stubs(:create).returns(session)

    post portal_billing_path

    assert_redirected_to "https://billing.stripe.test/session"
  ensure
    Stripe.api_key = original_key
  end
end
