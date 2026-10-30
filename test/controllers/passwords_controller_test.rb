require "test_helper"

class PasswordsControllerTest < ActionDispatch::IntegrationTest
  include ActionMailer::TestHelper

  test "password recovery sends a usable reset link" do
    travel_to Time.current.change(usec: 0)
    user = create_user("password-reset@example.com")
    session = user.sessions.create!

    assert_emails 1 do
      perform_enqueued_jobs do
        post passwords_path, params: { email_address: " PASSWORD-RESET@example.com " }
      end
    end
    assert_redirected_to new_session_path

    email = ActionMailer::Base.deliveries.last
    assert_equal [ user.email_address ], email.to
    reset_url = edit_password_url(user.password_reset_token, host: "example.com")
    assert_includes email.text_part.body.decoded, reset_url
    assert_includes email.html_part.body.decoded, reset_url

    get edit_password_path(user.password_reset_token)
    assert_response :success

    token = user.password_reset_token
    patch password_path(token), params: { password: "new-password", password_confirmation: "new-password" }
    assert_redirected_to new_session_path
    assert user.reload.authenticate("new-password")
    assert_not Session.exists?(session.id)

    get edit_password_path(token)
    assert_redirected_to new_password_path
  end

  test "unknown email receives the same response without sending mail" do
    assert_no_enqueued_emails do
      post passwords_path, params: { email_address: "unknown@example.com" }
    end
    assert_redirected_to new_session_path
    assert_equal I18n.t("flashes.reset_sent"), flash[:notice]
  end

  test "invalid reset token is rejected" do
    get edit_password_path("invalid")
    assert_redirected_to new_password_path
  end
end
