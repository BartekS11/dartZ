require "test_helper"

class Api::V1::MatchesControllerTest < ActionDispatch::IntegrationTest
  setup do
    post "/api/v1/auth/guest"
    @token = response.parsed_body.fetch("token")
    @headers = { "Authorization" => "Bearer #{@token}" }
  end

  test "guest list summary and full state responses preserve their complete contracts" do
    post "/api/v1/matches", params: {
      player1_name: "API Alice",
      player2_name: "API Bob",
      starting_score: 301,
      best_of_legs: 3,
      best_of_sets: 1,
      double_in: false,
      double_out: true
    }, headers: @headers

    assert_response :created
    match = Match.find_by_public_id!(response.parsed_body.fetch("id"))
    alice, bob = match.players.order(:created_at).to_a
    current_turn = match.match_sets.order(:created_at).last.legs.order(:created_at).last.turns.order(:created_at).last

    expected_state = {
      "id" => match.public_id,
      "match_identifier" => match.match_identifier,
      "ui_identifier" => match.ui_identifier,
      "finished" => false,
      "best_of_legs" => 3,
      "best_of_sets" => 1,
      "starting_score" => 301,
      "double_in" => false,
      "double_out" => true,
      "winner" => nil,
      "current_player" => "API Alice",
      "current_turn_id" => current_turn.public_id,
      "players" => [
        {
          "id" => alice.public_id,
          "name" => "API Alice",
          "score" => 301,
          "avg" => 0.0,
          "sets_won" => 0,
          "legs_won" => 0,
          "winner" => false,
          "last_throws" => [],
          "checkout" => nil
        },
        {
          "id" => bob.public_id,
          "name" => "API Bob",
          "score" => 301,
          "avg" => 0.0,
          "sets_won" => 0,
          "legs_won" => 0,
          "winner" => false,
          "last_throws" => [],
          "checkout" => nil
        }
      ]
    }
    assert_equal expected_state, response.parsed_body

    get "/api/v1/matches/#{match.public_id}", headers: @headers
    assert_response :success
    assert_equal expected_state, response.parsed_body

    get "/api/v1/matches", headers: @headers
    assert_response :success
    assert_equal [ {
      "id" => match.public_id,
      "match_identifier" => match.match_identifier,
      "ui_identifier" => match.ui_identifier,
      "finished" => false,
      "starting_score" => 301,
      "game_mode_labels" => match.game_mode_labels,
      "players" => [
        { "id" => alice.public_id, "name" => "API Alice", "score" => 301, "avg" => 0.0, "winner" => false },
        { "id" => bob.public_id, "name" => "API Bob", "score" => 301, "avg" => 0.0, "winner" => false }
      ],
      "created_at" => match.created_at.iso8601,
      "best_of_legs" => 3,
      "best_of_sets" => 1
    } ], response.parsed_body
  end
end
