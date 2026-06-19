require "test_helper"

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
    assert_select "button", text: /Upgrade with Stripe soon/
  end
end
