require "test_helper"

class PlayoffProgressorTest < ActiveSupport::TestCase
  test "semifinal and final can use custom best of legs" do
    tournament = Tournament.create!(
      title: "Custom Finals",
      format_type: "playoffs",
      best_of_legs: 1,
      best_of_sets: 1,
      playoff_best_of_legs: 1,
      semifinal_best_of_legs: 3,
      final_best_of_legs: 5,
      seeding_mode: "manual",
      playoff_mode: "single_elimination"
    )

    4.times { |i| tournament.entries.create!(name: "Seed #{i + 1}", seed: i + 1) }
    TournamentGenerator.new(tournament).call

    semi_round = tournament.rounds.find_by!(bracket: "upper", number: 1)
    assert_equal [ 3, 3 ], semi_round.tournament_matches.order(:position).pluck(:best_of_legs)

    semi_round.tournament_matches.order(:position).each do |match|
      match.update!(winner_entry: match.home_entry, home_legs: 2, status: "complete", completed_at: Time.current)
    end

    TournamentProgressor.new(tournament).call

    final_match = tournament.rounds.find_by!(bracket: "final").tournament_matches.first
    assert_equal 5, final_match.best_of_legs
  end

  test "single elimination creates only one final when progressor runs repeatedly" do
    tournament = Tournament.create!(
      title: "No Duplicate Final",
      format_type: "playoffs",
      best_of_legs: 1,
      best_of_sets: 1,
      seeding_mode: "manual",
      playoff_mode: "single_elimination"
    )

    4.times { |i| tournament.entries.create!(name: "Seed #{i + 1}", seed: i + 1) }
    TournamentGenerator.new(tournament).call

    semi_round = tournament.rounds.find_by!(bracket: "upper", number: 1)
    semi_round.tournament_matches.order(:position).each do |match|
      match.update!(winner_entry: match.home_entry, home_legs: 1, status: "complete", completed_at: Time.current)
    end

    3.times { TournamentProgressor.new(tournament).call }

    assert_equal 1, tournament.rounds.where(stage_type: "playoffs", bracket: "final").count
    assert_equal 1, tournament.rounds.where(stage_type: "playoffs", name: "Grand Final").count
  end

  test "completed groups tournament automatically generates playoff ladder" do
    tournament = Tournament.create!(
      title: "Groups Auto Ladder",
      format_type: "groups",
      best_of_legs: 1,
      best_of_sets: 1,
      group_count: 2,
      qualifiers_per_group: 1,
      seeding_mode: "manual",
      playoff_mode: "single_elimination"
    )

    a1 = tournament.entries.create!(name: "A1", seed: 1, group_name: "A")
    a2 = tournament.entries.create!(name: "A2", seed: 2, group_name: "A")
    b1 = tournament.entries.create!(name: "B1", seed: 3, group_name: "B")
    b2 = tournament.entries.create!(name: "B2", seed: 4, group_name: "B")
    round_a = tournament.rounds.create!(number: 1, name: "Group A", stage_type: "groups", group_name: "A", status: "complete")
    round_b = tournament.rounds.create!(number: 2, name: "Group B", stage_type: "groups", group_name: "B", status: "complete")
    round_a.tournament_matches.create!(tournament: tournament, home_entry: a1, away_entry: a2, winner_entry: a1, home_legs: 1, status: "complete", position: 1, best_of_legs: 1, best_of_sets: 1)
    round_b.tournament_matches.create!(tournament: tournament, home_entry: b1, away_entry: b2, winner_entry: b1, home_legs: 1, status: "complete", position: 1, best_of_legs: 1, best_of_sets: 1)

    TournamentProgressor.new(tournament).call

    playoff_round = tournament.rounds.find_by(stage_type: "playoffs")
    assert_not_nil playoff_round
    assert_equal 1, playoff_round.tournament_matches.count
  end

  test "group playoff qualifiers avoid same group first round pairings" do
    tournament = Tournament.create!(
      title: "Cross Group Playoff",
      format_type: "groups_playoffs",
      best_of_legs: 1,
      best_of_sets: 1,
      group_count: 2,
      qualifiers_per_group: 2,
      seeding_mode: "manual",
      playoff_mode: "single_elimination"
    )

    a1 = tournament.entries.create!(name: "A1", seed: 1, group_name: "A", wins: 3, points: 3, legs_for: 3)
    a2 = tournament.entries.create!(name: "A2", seed: 2, group_name: "A", wins: 2, points: 2, legs_for: 2)
    b1 = tournament.entries.create!(name: "B1", seed: 3, group_name: "B", wins: 3, points: 3, legs_for: 3)
    b2 = tournament.entries.create!(name: "B2", seed: 4, group_name: "B", wins: 2, points: 2, legs_for: 2)

    round_a = tournament.rounds.create!(number: 1, name: "Group A", stage_type: "groups", group_name: "A", status: "complete")
    round_b = tournament.rounds.create!(number: 2, name: "Group B", stage_type: "groups", group_name: "B", status: "complete")
    round_a.tournament_matches.create!(tournament: tournament, home_entry: a1, away_entry: a2, winner_entry: a1, home_legs: 1, status: "complete", position: 1, best_of_legs: 1, best_of_sets: 1)
    round_b.tournament_matches.create!(tournament: tournament, home_entry: b1, away_entry: b2, winner_entry: b1, home_legs: 1, status: "complete", position: 1, best_of_legs: 1, best_of_sets: 1)

    TournamentProgressor.new(tournament).call

    playoff_matches = tournament.rounds.find_by!(stage_type: "playoffs", number: 3).tournament_matches.order(:position)
    assert_equal 2, playoff_matches.count
    playoff_matches.each do |match|
      refute_equal match.home_entry.group_name, match.away_entry.group_name, "#{match.label} should cross groups"
    end
  end

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
