require "test_helper"

class PasswordChangesControllerTest < ActionDispatch::IntegrationTest
  setup do
    @user = create_user("temporary@example.com")
    @old_session = @user.sessions.create!
    @temporary_password = @user.issue_temporary_password!
  end

  test "temporary password revokes sessions and gates access until replaced" do
    assert_not Session.exists?(@old_session.id)
    assert_not @user.reload.authenticate("password")
    assert @user.authenticate(@temporary_password)

    login_as(@user, password: @temporary_password)
    assert_redirected_to edit_password_change_path
    get root_path
    assert_redirected_to edit_password_change_path
    get edit_password_change_path
    assert_response :success

    patch password_change_path, params: { password: "my-new-password-123", password_confirmation: "my-new-password-123" }
    assert_redirected_to root_url
    assert_not @user.reload.password_change_required?
    assert @user.authenticate("my-new-password-123")
    assert_not @user.authenticate(@temporary_password)
    get root_path
    assert_response :success
  end

  test "rejects empty mismatched short and reused passwords" do
    login_as(@user, password: @temporary_password)
    [ [ "", "" ], [ "short", "short" ], [ "long-new-password", "different" ], [ @temporary_password, @temporary_password ] ].each do |password, confirmation|
      patch password_change_path, params: { password: password, password_confirmation: confirmation }
      assert_response :unprocessable_entity
      assert @user.reload.password_change_required?
      assert @user.authenticate(@temporary_password)
    end
  end

  test "requires login and permits signing out" do
    patch password_change_path, params: { password: "long-new-password", password_confirmation: "long-new-password" }
    assert_redirected_to new_session_path
    login_as(@user, password: @temporary_password)
    delete session_path
    assert_redirected_to new_session_path
  end

  test "reissuing a temporary password invalidates the previous one" do
    replacement = @user.issue_temporary_password!
    assert_not @user.reload.authenticate(@temporary_password)
    assert @user.authenticate(replacement)
  end
end
