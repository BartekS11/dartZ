require "test_helper"

class PlayoffProgressorTest < ActiveSupport::TestCase
  test "single elimination creates final and bronze match then completes tournament" do
    tournament = Tournament.create!(
      title: "Knockout",
      format_type: "playoffs",
      best_of_legs: 3,
      best_of_sets: 1,
      seeding_mode: "manual",
      bronze_match: true,
      playoff_mode: "single_elimination"
    )

    4.times do |i|
      tournament.entries.create!(name: "Seed #{i + 1}", seed: i + 1)
    end

    TournamentGenerator.new(tournament).call
    semi_round = tournament.rounds.find_by(bracket: "upper", number: 1)
    semi_round.tournament_matches.order(:position).each do |match|
      match.update!(winner_entry: match.home_entry, home_legs: 3, away_legs: 1, status: "complete", completed_at: Time.current)
    end

    TournamentProgressor.new(tournament).call

    assert_not_nil tournament.reload.rounds.find_by(bracket: "final")
    assert_not_nil tournament.rounds.find_by(bracket: "bronze")

    tournament.rounds.find_by(bracket: "final").tournament_matches.first.update!(winner_entry: tournament.rounds.find_by(bracket: "final").tournament_matches.first.home_entry, home_legs: 3, away_legs: 0, status: "complete", completed_at: Time.current)
    tournament.rounds.find_by(bracket: "bronze").tournament_matches.first.update!(winner_entry: tournament.rounds.find_by(bracket: "bronze").tournament_matches.first.home_entry, home_legs: 3, away_legs: 2, status: "complete", completed_at: Time.current)

    TournamentProgressor.new(tournament).call

    assert_equal "complete", tournament.reload.status
  end
end
