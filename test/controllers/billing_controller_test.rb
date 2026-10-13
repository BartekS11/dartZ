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
    assert_includes response.body, "Anonymous, revocable match-result links"
    assert_includes response.body, "Detailed leg-by-leg reviews and checkout performance"
    assert_includes response.body, "Evidence-based training recommendations"
    assert_not_includes response.body, "Future league tools"
    assert_not_includes response.body, "Priority features"
    assert_select "select[name='billing_interval']"
    assert_select "form[action='#{checkout_billing_path(tier: "premium", interval: "month", currency: "usd")}']"
    assert_select "form[action='#{checkout_billing_path(tier: "pro", interval: "month", currency: "usd")}']"
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

  test "english billing page offers usd and gbp pricing options" do
    user = create_user("gbp-billing@example.com")
    login_as(user)

    get billing_path(currency: "gbp")

    assert_response :success
    assert_select "select[name='currency'] option[value='usd']"
    assert_select "select[name='currency'] option[value='gbp']"
    assert_select "select[name='currency'] option[value='pln']"
    assert_includes response.body, "£3.99"
    assert_includes response.body, "GBP"
  end

  test "polish locale displays pln pricing" do
    user = create_user("pln-billing@example.com")
    login_as(user)

    get billing_path(locale: "pl")

    assert_response :success
    assert_includes response.body, "9,99 zł"
    assert_includes response.body, "PLN"
  end

  test "checkout rejects invalid tier" do
    user = create_user("bad-tier@example.com")
    login_as(user)

    post checkout_billing_path(tier: "free")

    assert_redirected_to billing_path
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

  test "switching a cancelled subscriber tier resumes the existing subscription without a second checkout" do
    user = create_user("switch-tier@example.com")
    user.update!(account_tier: "premium", stripe_subscription_id: "sub_existing", stripe_subscription_status: "active", stripe_cancel_at_period_end: true)
    login_as(user)
    original_key = Stripe.api_key
    Stripe.api_key = "stripe_secret_key_fake"
    item = OpenStruct.new(id: "si_existing", price: OpenStruct.new(currency: "usd", recurring: OpenStruct.new(interval: "month")))
    current = OpenStruct.new(id: "sub_existing", items: OpenStruct.new(data: [ item ]))
    updated = OpenStruct.new(
      id: "sub_existing", status: "active", current_period_end: 1.month.from_now.to_i,
      items: OpenStruct.new(data: [ OpenStruct.new(price: OpenStruct.new(id: "price_pro_usd")) ])
    )
    Stripe::Subscription.expects(:retrieve).with("sub_existing").returns(current)
    StripeBilling::Configuration.expects(:price_id_for).with(tier: "pro", currency: "usd").returns("price_pro_usd")
    Stripe::Subscription.expects(:update).with(
      "sub_existing", items: [ { id: "si_existing", price: "price_pro_usd" } ], proration_behavior: "create_prorations", cancel_at_period_end: false
    ).returns(updated)

    post checkout_billing_path(tier: "pro", interval: "month")

    assert_redirected_to billing_path
    assert_equal "pro", user.reload.account_tier
    assert_equal "price_pro_usd", user.stripe_price_id
    assert_not user.stripe_cancel_at_period_end?
    assert_equal "Your subscription is active again and now on the new plan. Future renewals will continue as scheduled.", flash[:notice]
  ensure
    Stripe.api_key = original_key
  end

  test "yearly subscriber keeps yearly billing when switching tiers" do
    user = create_user("switch-yearly-tier@example.com")
    user.update!(account_tier: "premium", stripe_subscription_id: "sub_yearly", stripe_subscription_status: "active")
    login_as(user)
    original_key = Stripe.api_key
    Stripe.api_key = "stripe_secret_key_fake"
    item = OpenStruct.new(
      id: "si_yearly",
      price: OpenStruct.new(currency: "usd", product: "prod_premium", recurring: OpenStruct.new(interval: "year"))
    )
    current = OpenStruct.new(id: "sub_yearly", items: OpenStruct.new(data: [ item ]))
    updated = OpenStruct.new(
      id: "sub_yearly", status: "active", current_period_end: 1.year.from_now.to_i,
      items: OpenStruct.new(data: [ OpenStruct.new(price: OpenStruct.new(id: "price_pro_year")) ])
    )
    Stripe::Subscription.expects(:retrieve).with("sub_yearly").returns(current)
    StripeBilling::Configuration.expects(:price_id_for).with(tier: "pro", currency: "usd").returns("price_pro_month")
    Stripe::Price.expects(:retrieve).with("price_pro_month").returns(OpenStruct.new(product: "prod_pro"))
    Stripe::Price.expects(:create).with do |params|
      params[:currency] == "usd" && params[:unit_amount] == 8_991 &&
        params[:recurring] == { interval: "year" } && params[:product] == "prod_pro"
    end.returns(OpenStruct.new(id: "price_pro_year"))
    Stripe::Subscription.expects(:update).with(
      "sub_yearly", items: [ { id: "si_yearly", price: "price_pro_year" } ], proration_behavior: "create_prorations", cancel_at_period_end: false
    ).returns(updated)

    post checkout_billing_path(tier: "pro", interval: "month")

    assert_redirected_to billing_path
    assert_equal "pro", user.reload.account_tier
    assert_equal "price_pro_year", user.stripe_price_id
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

  test "subscription cancellation keeps access through the paid period" do
    user = create_user("cancel-subscription@example.com")
    paid_until = 1.month.from_now
    user.update!(account_tier: "premium", stripe_subscription_id: "sub_cancel", stripe_subscription_status: "active", premium_access_expires_at: paid_until)
    login_as(user)
    original_key = Stripe.api_key
    Stripe.api_key = "stripe_secret_key_fake"
    subscription = OpenStruct.new(id: "sub_cancel", cancel_at_period_end: false)
    updated = OpenStruct.new(cancel_at_period_end: true)
    Stripe::Subscription.expects(:retrieve).with("sub_cancel").returns(subscription)
    Stripe::Subscription.expects(:update).with("sub_cancel", cancel_at_period_end: true).returns(updated)

    post cancel_subscription_billing_path

    assert_redirected_to billing_path
    assert_equal "premium", user.reload.account_tier
    assert user.stripe_cancel_at_period_end?
    assert_equal paid_until.to_i, user.premium_access_expires_at.to_i
    assert_equal "Your subscription is set to end after the current paid period. You’ll keep access until then.", flash[:notice]
  ensure
    Stripe.api_key = original_key
  end

  test "cancellation releases a pending billing schedule before ending at period end" do
    user = create_user("scheduled-cancel-subscription@example.com")
    user.update!(account_tier: "premium", stripe_subscription_id: "sub_cancel", stripe_subscription_status: "active")
    login_as(user)
    original_key = Stripe.api_key
    Stripe.api_key = "stripe_secret_key_fake"
    subscription = OpenStruct.new(id: "sub_cancel", cancel_at_period_end: false, schedule: OpenStruct.new(id: "sched_cancel"))
    Stripe::Subscription.stubs(:retrieve).with("sub_cancel").returns(subscription)
    Stripe::SubscriptionSchedule.expects(:release).with("sched_cancel")
    Stripe::Subscription.expects(:update).with("sub_cancel", cancel_at_period_end: true).returns(OpenStruct.new(cancel_at_period_end: true))

    post cancel_subscription_billing_path

    assert user.reload.stripe_cancel_at_period_end?
  ensure
    Stripe.api_key = original_key
  end

  test "already scheduled cancellation is not submitted again" do
    user = create_user("already-cancelled-subscription@example.com")
    user.update!(account_tier: "premium", stripe_subscription_id: "sub_cancel", stripe_subscription_status: "active")
    login_as(user)
    original_key = Stripe.api_key
    Stripe.api_key = "stripe_secret_key_fake"
    Stripe::Subscription.stubs(:retrieve).with("sub_cancel").returns(OpenStruct.new(id: "sub_cancel", cancel_at_period_end: true))
    Stripe::Subscription.expects(:update).never

    post cancel_subscription_billing_path

    assert user.reload.stripe_cancel_at_period_end?
    assert_equal "Your subscription is already set to end after the current paid period.", flash[:notice]
  ensure
    Stripe.api_key = original_key
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
