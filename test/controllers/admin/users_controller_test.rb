require "test_helper"

class Admin::UsersControllerTest < ActionDispatch::IntegrationTest
  setup do
    @admin = AdminUser.create!(email_address: "users-admin@example.com", password: "a-secure-password-123")
    @user = create_user("player@example.com")
    post admin_login_path, params: { email_address: @admin.email_address, password: "a-secure-password-123" }
  end

  test "lists and searches users" do
    get admin_users_path, params: { query: "player@" }

    assert_response :success
    assert_select "td", text: /player@example.com/
  end

  test "clamps pagination to the available range" do
    get admin_users_path, params: { page: 999 }

    assert_response :success
    assert_select "nav", text: /Page 1 of 1/
  end

  test "shows user and read-only Stripe state" do
    @user.update!(stripe_customer_id: "cus_test", stripe_subscription_status: "active")

    get admin_user_path(@user)

    assert_response :success
    assert_select "dd", text: "cus_test"
    assert_select "h2", text: "Tier control"
  end

  test "applies audited override" do
    patch tier_admin_user_path(@user), params: { manual_tier_override: "premium", reason: "Support grant" }

    assert_redirected_to admin_user_path(@user)
    assert_equal "premium", @user.reload.manual_tier_override
    assert_equal "Support grant", @user.admin_tier_changes.last.reason
  end

  test "rejects downgrade without a reason" do
    @user.update!(manual_tier_override: "pro")

    patch tier_admin_user_path(@user), params: { manual_tier_override: "free", reason: "" }

    assert_redirected_to admin_user_path(@user)
    assert_equal "pro", @user.reload.manual_tier_override
  end

  test "browses and filters invitation and bot matches" do
    invitation = Match.create!(invite_created_at: Time.current)
    invitation.players.create!(name: "Player", user: @user)
    invitation.players.create!(name: "Guest")
    bot_match = Match.create!
    bot_match.players.create!(name: "Player", user: @user)
    bot_match.players.create!(name: "Bot", bot: true)

    get matches_admin_user_path(@user, filter: "invitation")
    assert_response :success
    assert_select "article", count: 1
    assert_select ".theme-chip", text: /Invitation/, minimum: 1

    get matches_admin_user_path(@user, filter: "bot")
    assert_response :success
    assert_select "article", count: 1
    assert_includes response.body, ">Bot</span>"
  end
end
