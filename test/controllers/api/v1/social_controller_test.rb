require "test_helper"

class Api::V1::SocialControllerTest < ActionDispatch::IntegrationTest
  setup do
    @alice = create_user("api-social-alice-#{SecureRandom.hex(4)}@example.com")
    @bob = create_user("api-social-bob-#{SecureRandom.hex(4)}@example.com")
    @alice.update!(nickname: "Alice")
    @bob.update!(nickname: "Bob", discoverable_by_nickname: true)
    @alice_headers = auth_headers(@alice)
    @bob_headers = auth_headers(@bob)
    FeatureAccess.stubs(:enabled?).with(:friends).returns(true)
  end

  test "exact discovery is paginated and never leaks email or database ids" do
    get "/api/v1/users/search", params: { nickname: "Bob", page: 1, per_page: 10 }, headers: @alice_headers

    assert_response :success
    assert_equal @bob.public_id, response.parsed_body.dig("data", 0, "id")
    assert_equal 10, response.parsed_body.dig("pagination", "per_page")
    assert_not_includes response.body, @bob.email_address
    refute_match(/\"user_id\"|\"blocked\"/, response.body)

    get "/api/v1/users/search", params: { nickname: @bob.email_address }, headers: @alice_headers
    assert_response :success
    assert_empty response.parsed_body.fetch("data")
  end

  test "request acceptance and collections use public data" do
    post "/api/v1/friend_requests", params: { share_code: @bob.friend_share_code }, headers: @alice_headers, as: :json
    assert_response :created
    request_id = response.parsed_body.dig("data", "id")

    get "/api/v1/friend_requests", headers: @bob_headers
    assert_response :success
    assert_equal "incoming", response.parsed_body.dig("data", 0, "direction")

    post "/api/v1/friend_requests/#{request_id}/accept", headers: @bob_headers, as: :json
    assert_response :success
    friendship_id = response.parsed_body.dig("data", "id")

    get "/api/v1/friendships", headers: @alice_headers
    assert_response :success
    assert_equal friendship_id, response.parsed_body.dig("data", 0, "id")
    assert_not_includes response.body, @bob.email_address
  end

  test "challenge acceptance returns existing remote match identifiers" do
    Friendship.create_between!(@alice, @bob)
    post "/api/v1/challenges", params: {
      user_id: @bob.public_id,
      starting_score: 301,
      best_of_legs: 3,
      best_of_sets: 1,
      double_out: true
    }, headers: @alice_headers, as: :json
    assert_response :created
    challenge_id = response.parsed_body.dig("data", "id")

    post "/api/v1/challenges/#{challenge_id}/accept", headers: @bob_headers, as: :json
    assert_response :success
    assert_match(/\Am_/, response.parsed_body.dig("data", "match_id"))
    assert_match(/\Ap_/, response.parsed_body.dig("data", "player_id"))
    assert_equal "accepted", response.parsed_body.dig("data", "status")
    assert_not_includes response.body, "invite_token"
  end

  test "blocking conceals discovery and cancels relationship" do
    Friendship.create_between!(@alice, @bob)
    post "/api/v1/blocks", params: { user_id: @bob.public_id }, headers: @alice_headers, as: :json
    assert_response :created
    block_id = response.parsed_body.dig("data", "id")

    get "/api/v1/users/search", params: { nickname: "Alice" }, headers: @bob_headers
    assert_response :success
    assert_empty response.parsed_body.fetch("data")

    delete "/api/v1/blocks/#{block_id}", headers: @alice_headers
    assert_response :no_content
  end

  test "settings, authentication, guest access, and disabled flag follow roadmap envelopes" do
    get "/api/v1/friend_settings", headers: @alice_headers
    assert_response :success
    assert_equal "share_code_only", response.parsed_body.dig("data", "friend_request_policy")

    patch "/api/v1/friend_settings", params: { friend_request_policy: "nobody" }, headers: @alice_headers, as: :json
    assert_response :success

    get "/api/v1/friendships"
    assert_response :unauthorized

    guest_headers = { "Authorization" => "Bearer #{JsonWebToken.encode(guest: true, guest_id: SecureRandom.uuid)}" }
    get "/api/v1/friendships", headers: guest_headers
    assert_response :forbidden
    assert_equal "feature_forbidden", response.parsed_body.dig("error", "code")

    FeatureAccess.unstub(:enabled?)
    FeatureAccess.stubs(:enabled?).with(:friends).returns(false)
    get "/api/v1/friendships", headers: @alice_headers
    assert_response :not_found
    assert_equal "feature_unavailable", response.parsed_body.dig("error", "code")
  end

  private

  def auth_headers(user)
    { "Authorization" => "Bearer #{JsonWebToken.encode(user_id: user.id)}" }
  end
end
