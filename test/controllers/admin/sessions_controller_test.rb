require "test_helper"

class Admin::SessionsControllerTest < ActionDispatch::IntegrationTest
  setup do
    @admin = AdminUser.create!(email_address: "operator@example.com", password: "a-secure-password-123")
  end

  test "configured login path authenticates an admin" do
    get admin_login_path
    assert_response :success
    assert_equal "noindex, nofollow, noarchive", response.headers["X-Robots-Tag"]

    post admin_login_path, params: { email_address: @admin.email_address, password: "a-secure-password-123" }
    assert_redirected_to admin_root_path

    follow_redirect!
    assert_response :success
    assert_select "h1", "Overview"
  end

  test "invalid credentials use a generic error" do
    post admin_login_path, params: { email_address: @admin.email_address, password: "wrong-password" }

    assert_redirected_to admin_login_path
    follow_redirect!
    assert_select ".theme-notification", text: /Invalid credentials/
  end

  test "conventional admin path is not routed" do
    get "/admin"

    assert_response :not_found
  end

  test "protected pages return not found without an admin session" do
    get admin_root_path
    assert_response :not_found

    user = create_user("normal@example.com")
    login_as(user)
    get admin_users_path
    assert_response :not_found
  end

  test "login removes expired admin sessions" do
    expired = @admin.admin_sessions.create!(expires_at: 1.minute.ago)

    post admin_login_path, params: { email_address: @admin.email_address, password: "a-secure-password-123" }

    assert_not AdminSession.exists?(expired.id)
    assert_equal 1, @admin.admin_sessions.count
  end

  test "logout invalidates the admin session" do
    post admin_login_path, params: { email_address: @admin.email_address, password: "a-secure-password-123" }
    delete admin_logout_path
    assert_redirected_to admin_login_path

    get admin_root_path
    assert_response :not_found
  end

  test "expired admin sessions return not found" do
    post admin_login_path, params: { email_address: @admin.email_address, password: "a-secure-password-123" }
    session = @admin.admin_sessions.order(:created_at).last
    session.update!(expires_at: 1.minute.ago)

    get admin_root_path

    assert_response :not_found
    assert_not AdminSession.exists?(session.id)
  end
end
