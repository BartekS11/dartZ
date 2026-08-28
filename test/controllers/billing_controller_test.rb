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
    assert_select "form[action='#{checkout_billing_path(tier: "premium")}']"
    assert_select "form[action='#{checkout_billing_path(tier: "pro")}']"
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

    Stripe::Checkout::Session.expects(:create).never

    post checkout_billing_path(tier: "pro")

    assert_redirected_to billing_path
    assert_equal "Manage your active subscription in the Stripe customer portal.", flash[:alert]
  end

  test "checkout creates stripe session" do
    user = create_user("checkout@example.com")
    login_as(user)
    original_key = Stripe.api_key
    Stripe.api_key = "sk_test_fake"

    customer = OpenStruct.new(id: "cus_test")
    session = OpenStruct.new(url: "https://checkout.stripe.test/session")

    StripeBilling::Configuration.stubs(:price_id_for).returns("price_test")
    Stripe::Customer.stubs(:create).returns(customer)
    Stripe::Checkout::Session.stubs(:create).returns(session)

    post checkout_billing_path(tier: "premium")

    assert_redirected_to "https://checkout.stripe.test/session"
    assert_equal "cus_test", user.reload.stripe_customer_id
  ensure
    Stripe.api_key = original_key
  end

  test "portal creates stripe portal session" do
    user = create_user("portal@example.com")
    user.update!(stripe_customer_id: "cus_test")
    login_as(user)
    original_key = Stripe.api_key
    Stripe.api_key = "sk_test_fake"

    session = OpenStruct.new(url: "https://billing.stripe.test/session")
    Stripe::BillingPortal::Session.stubs(:create).returns(session)

    post portal_billing_path

    assert_redirected_to "https://billing.stripe.test/session"
  ensure
    Stripe.api_key = original_key
  end
end
