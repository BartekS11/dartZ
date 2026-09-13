require "test_helper"

class Api::V1::AuthenticationContractTest < ActionDispatch::IntegrationTest
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
