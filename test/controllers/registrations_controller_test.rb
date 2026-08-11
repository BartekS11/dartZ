require "test_helper"

class RegistrationsControllerTest < ActionDispatch::IntegrationTest
  test "should get new" do
    get new_registration_path

    assert_response :success
    assert_select "form[action='#{registration_path}']"
  end

  test "creates free user and starts session" do
    assert_difference("User.count", 1) do
      post registration_path, params: {
        user: {
          email_address: "new@example.com",
          nickname: "Newbie",
          password: "password",
          password_confirmation: "password"
        }
      }
    end

    user = User.find_by!(email_address: "new@example.com")
    assert_equal "Newbie", user.nickname
    assert_equal "free", user.account_tier
    assert_redirected_to matches_path
    assert cookies.signed[:session_id].present?
    assert_equal user, Session.find(cookies.signed[:session_id]).user
  end

  test "does not create user with mismatched password confirmation" do
    assert_no_difference("User.count") do
      post registration_path, params: {
        user: {
          email_address: "bad@example.com",
          nickname: "Bad",
          password: "password",
          password_confirmation: "different"
        }
      }
    end

    assert_response :unprocessable_entity
  end

  test "does not create duplicate email" do
    User.create!(email_address: "taken@example.com", password: "password")

    assert_no_difference("User.count") do
      post registration_path, params: {
        user: {
          email_address: "taken@example.com",
          password: "password",
          password_confirmation: "password"
        }
      }
    end

    assert_response :unprocessable_entity
  end
end
