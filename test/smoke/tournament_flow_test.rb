require "test_helper"

class TournamentFlowTest < ActionDispatch::IntegrationTest
  test "guest admin can create tournament join player and report result" do
    post tournaments_path, params: {
      tournament: {
        title: "Weekend Bracket",
        format_type: "playoffs",
        best_of_legs: 3,
        best_of_sets: 1,
        playoff_mode: "single_elimination",
        entry_names: "Alpha\nBravo"
      }
    }

    tournament = Tournament.order(:created_at).last

    post start_tournament_path(tournament, admin_token: tournament.admin_token)

    match = tournament.tournament_matches.first
    patch report_tournament_tournament_match_path(tournament, match, admin_token: tournament.admin_token), params: {
      home_sets: 0,
      away_sets: 0,
      home_legs: 3,
      away_legs: 1
    }

    assert_redirected_to tournament_path(tournament, admin_token: tournament.admin_token)
    assert_equal "complete", match.reload.status
    assert_equal "complete", tournament.reload.status
  end
end
