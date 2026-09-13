require "test_helper"

class Api::V1::TrainingSessionsControllerTest < ActionDispatch::IntegrationTest
  setup do
    @user = create_user("api-training-#{SecureRandom.hex(4)}@example.com")
    @user.update!(account_tier: "premium")
    @headers = { "Authorization" => "Bearer #{JsonWebToken.encode(user_id: @user.id)}" }
    FeatureAccess.stubs(:enabled?).with(:expanded_training).returns(true)
  end

  test "lists mode definitions and creates a resumable session" do
    get "/api/v1/training/modes", headers: @headers
    assert_response :success
    assert_equal TrainingSession::EXPANDED_MODES, response.parsed_body.fetch("data").pluck("mode")

    post "/api/v1/training/sessions", params: { mode: "doubles_practice", configuration: { from: 19, to: 20 } }, headers: @headers, as: :json
    assert_response :created
    id = response.parsed_body.dig("data", "id")

    get "/api/v1/training/sessions/#{id}", headers: @headers
    assert_response :success
    assert_equal "D19", response.parsed_body.dig("data", "current_target", "label")
  end

  test "attempt submission is idempotent and rejects excess hits" do
    session = Training::SessionStarter.call(user: @user, mode: "doubles_practice", configuration: { from: 19, to: 20 })
    key = SecureRandom.uuid
    payload = { idempotency_key: key, result: { hits: 2 } }

    post "/api/v1/training/sessions/#{session.public_id}/attempts", params: payload, headers: @headers, as: :json
    assert_response :created
    original = response.parsed_body
    post "/api/v1/training/sessions/#{session.public_id}/attempts", params: { idempotency_key: SecureRandom.uuid, result: { hits: 1 } }, headers: @headers, as: :json
    assert_response :created
    post "/api/v1/training/sessions/#{session.public_id}/attempts", params: payload.deep_merge(result: { hits: 3 }), headers: @headers, as: :json
    assert_response :created
    assert_equal original, response.parsed_body
    assert_equal 2, session.training_attempts.count

    other = Training::SessionStarter.call(user: @user, mode: "doubles_practice", configuration: { from: 20, to: 20 })
    post "/api/v1/training/sessions/#{other.public_id}/attempts", params: { idempotency_key: SecureRandom.uuid, result: { hits: 4 } }, headers: @headers, as: :json
    assert_response :unprocessable_entity
  end

  test "finished session returns conflict and collections paginate and filter" do
    session = Training::SessionStarter.call(user: @user, mode: "custom_targets", configuration: { targets: [ "IB" ] })
    Training::AttemptRecorder.call(session: session, idempotency_key: SecureRandom.uuid, result: { hits: 1 })

    post "/api/v1/training/sessions/#{session.public_id}/attempts", params: { idempotency_key: SecureRandom.uuid, result: { hits: 1 } }, headers: @headers, as: :json
    assert_response :conflict

    get "/api/v1/training/sessions", params: { status: "completed", page: 1, per_page: 1 }, headers: @headers
    assert_response :success
    assert_equal 1, response.parsed_body.fetch("data").size
    assert_equal 1, response.parsed_body.dig("pagination", "per_page")
  end

  test "requires authentication flag and premium entitlement" do
    get "/api/v1/training/modes"
    assert_response :unauthorized

    FeatureAccess.unstub(:enabled?)
    FeatureAccess.stubs(:enabled?).with(:expanded_training).returns(false)
    get "/api/v1/training/modes", headers: @headers
    assert_response :not_found

    FeatureAccess.unstub(:enabled?)
    FeatureAccess.stubs(:enabled?).with(:expanded_training).returns(true)
    free = create_user("free-api-training-#{SecureRandom.hex(4)}@example.com")
    get "/api/v1/training/modes", headers: { "Authorization" => "Bearer #{JsonWebToken.encode(user_id: free.id)}" }
    assert_response :forbidden
  end
end
