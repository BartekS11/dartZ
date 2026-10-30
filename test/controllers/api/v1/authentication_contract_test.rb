require "test_helper"

class Api::V1::AuthenticationContractTest < ActionDispatch::IntegrationTest
  test "temporary passwords cannot bypass the required website password change" do
    user = create_user("temporary-api@example.com")
    token = JsonWebToken.encode(user_id: user.id)
    temporary_password = user.issue_temporary_password!

    get "/api/v1/matches", headers: { "Authorization" => "Bearer #{token}" }
    assert_response :forbidden

    post "/api/v1/auth/login", params: { email: user.email_address, password: temporary_password }
    assert_response :forbidden
    assert_not response.parsed_body.key?("token")
  end

  test "missing bearer token preserves the legacy unauthorized envelope" do
    get "/api/v1/matches"

    assert_response :unauthorized
    assert_equal({ "error" => "Missing token" }, response.parsed_body)
  end

  test "invalid bearer token preserves the legacy unauthorized envelope" do
    get "/api/v1/matches", headers: { "Authorization" => "Bearer invalid-token" }

    assert_response :unauthorized
    assert_kind_of String, response.parsed_body.fetch("error")
    assert_equal [ "error" ], response.parsed_body.keys
  end

  test "guest authentication preserves its existing response shape" do
    post "/api/v1/auth/guest"

    assert_response :success
    assert_equal [ "guest", "token" ], response.parsed_body.keys.sort
    assert_equal true, response.parsed_body.fetch("guest")
    assert_predicate response.parsed_body.fetch("token"), :present?
  end
end
