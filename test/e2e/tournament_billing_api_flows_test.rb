# frozen_string_literal: true

require "e2e_helper"
require "ostruct"

class TournamentBillingApiFlowsTest < E2EIntegrationTest
  test "guest tournament can be created started and completed by reported result" do
    post tournaments_path, params: {
      tournament: {
        title: "E2E Weekend Bracket",
        format_type: "playoffs",
        best_of_legs: 1,
        best_of_sets: 1,
        playoff_mode: "single_elimination",
        entry_names: "Alpha\nBravo"
      }
    }

    tournament = Tournament.order(:created_at).last
    assert_redirected_to tournament_path(tournament, admin_token: tournament.admin_token)

    post start_tournament_path(tournament, admin_token: tournament.admin_token)
    assert_response :redirect

    tournament.reload
    match = tournament.tournament_matches.first
    assert_not_nil match

    patch report_tournament_tournament_match_path(tournament, match, admin_token: tournament.admin_token), params: {
      home_sets: 0,
      away_sets: 0,
      home_legs: 1,
      away_legs: 0
    }

    assert_redirected_to tournament_path(tournament, admin_token: tournament.admin_token)
    assert_equal "complete", match.reload.status
    assert_equal "complete", tournament.reload.status
  end

  test "mocked Stripe webhook grants premium access without external network" do
    user = create_user(unique_email("stripe-webhook"))
    subscription = OpenStruct.new(
      id: "sub_e2e",
      customer: "cus_e2e",
      status: "active",
      current_period_end: 1.month.from_now.to_i,
      metadata: OpenStruct.new(user_id: user.id, tier: "premium", currency: "usd"),
      items: OpenStruct.new(data: [ OpenStruct.new(price: OpenStruct.new(id: "price_e2e", currency: "usd")) ])
    )
    event = OpenStruct.new(
      type: "checkout.session.completed",
      data: OpenStruct.new(
        object: OpenStruct.new(
          client_reference_id: user.id,
          customer: "cus_e2e",
          subscription: "sub_e2e",
          metadata: OpenStruct.new(tier: "premium", currency: "usd")
        )
      )
    )

    StripeBilling::Configuration.stubs(:webhook_secret).returns("whsec_e2e")
    Stripe::Webhook.stubs(:construct_event).returns(event)
    Stripe::Subscription.stubs(:retrieve).returns(subscription)

    post "/stripe/webhooks", params: "{}", headers: {
      "CONTENT_TYPE" => "application/json",
      "HTTP_STRIPE_SIGNATURE" => "test-signature"
    }

    assert_response :success
    assert_equal "premium", user.reload.account_tier
    assert_equal "active", user.stripe_subscription_status
    assert user.premium_access?
  end

  test "API v1 guest can create a match and submit a turn total" do
    post "/api/v1/auth/guest"
    assert_response :success
    token = json_response.fetch("token")

    post "/api/v1/matches", params: {
      player1_name: "API Alice",
      player2_name: "API Bob",
      best_of_legs: 1,
      best_of_sets: 1
    }, headers: bearer(token)
    assert_response :created

    match_id = json_response.fetch("id")

    post "/api/v1/matches/#{match_id}/throws", params: { total: 60 }, headers: bearer(token)
    assert_response :created

    body = json_response
    assert_equal match_id, body.fetch("id")
    assert body.to_json.include?("441")
  end

  test "API v1 disabled flag returns service unavailable" do
    previous = Rails.configuration.x.api_v1_enabled
    Rails.configuration.x.api_v1_enabled = false

    post "/api/v1/auth/guest"
    assert_response :service_unavailable
    assert_equal "API v1 is disabled", json_response.fetch("error")
  ensure
    Rails.configuration.x.api_v1_enabled = previous
  end

  private

  def bearer(token)
    { "Authorization" => "Bearer #{token}" }
  end
end
