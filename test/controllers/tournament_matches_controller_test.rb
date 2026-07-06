require "test_helper"

class TournamentMatchesControllerTest < ActionDispatch::IntegrationTest
  test "launch prunes remembered guest tokens to avoid cookie overflow" do
    tournament = Tournament.create!(title: "Cookie Cup", format_type: "playoffs", best_of_legs: 1, best_of_sets: 1)
    round = tournament.rounds.create!(number: 1, name: "Round 1", stage_type: "playoffs", bracket: "upper", status: "active")

    tournament_matches = (ApplicationController::MAX_GUEST_MATCH_TOKENS + 5).times.map do |idx|
      home = tournament.entries.create!(name: "Home #{idx}", seed: (idx * 2) + 1)
      away = tournament.entries.create!(name: "Away #{idx}", seed: (idx * 2) + 2)
      round.tournament_matches.create!(tournament: tournament, home_entry: home, away_entry: away, position: idx + 1, best_of_legs: 1, best_of_sets: 1)
    end

    tournament_matches.each do |tournament_match|
      post launch_tournament_tournament_match_path(tournament, tournament_match, admin_token: tournament.admin_token)
      assert_redirected_to match_path(tournament_match.reload.linked_match, guest_token: tournament_match.linked_match.guest_token)
    end
  end

  test "launch creates a playable live match" do
    tournament = Tournament.create!(title: "Launch Cup", format_type: "playoffs", best_of_legs: 3, best_of_sets: 1)
    home = tournament.entries.create!(name: "Alpha", seed: 1)
    away = tournament.entries.create!(name: "Bravo", seed: 2)
    round = tournament.rounds.create!(number: 1, name: "Round 1", stage_type: "playoffs", bracket: "upper", status: "active")
    tournament_match = round.tournament_matches.create!(tournament: tournament, home_entry: home, away_entry: away, position: 1, best_of_legs: 3, best_of_sets: 1)

    post launch_tournament_tournament_match_path(tournament, tournament_match, admin_token: tournament.admin_token)

    match = Match.last
    assert_redirected_to match_path(match, guest_token: match.guest_token)
    assert_not_nil match.current_set
    assert_not_nil match.current_leg
    assert_not_nil match.current_leg.current_turn
    assert_equal "live", tournament_match.reload.status
    assert_equal match.id, tournament_match.linked_match_id
  end
end
