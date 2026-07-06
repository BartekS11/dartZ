require "test_helper"

class TournamentCoreLogicTest < ActiveSupport::TestCase
  test "tournament player stats aggregate throws across linked matches" do
    tournament = Tournament.create!(title: "Stats Core", format_type: "groups", best_of_legs: 1, best_of_sets: 1)
    home = tournament.entries.create!(name: "Alpha", seed: 1, group_name: "A", wins: 1, points: 1, legs_for: 1)
    away = tournament.entries.create!(name: "Bravo", seed: 2, group_name: "A", losses: 1, legs_against: 1)
    round = tournament.rounds.create!(number: 1, name: "Group A", stage_type: "groups", group_name: "A", status: "active")
    tournament_match = round.tournament_matches.create!(tournament: tournament, home_entry: home, away_entry: away, position: 1, best_of_legs: 1, best_of_sets: 1)
    linked_match = MatchCreator.call(
      settings: MatchSettings.from_tournament_match(tournament_match),
      players: [ { name: home.name }, { name: away.name } ],
      guest_match: true
    )
    tournament_match.update!(linked_match: linked_match, status: "live")

    turn = linked_match.current_leg.current_turn
    turn.distribute_total!(180)

    stat = TournamentPlayerStats.new(tournament).call.find { |player_stat| player_stat.entry == home }

    assert_equal 1, stat.matches_played
    assert_equal 1, stat.wins
    assert_equal 3, stat.darts_thrown
    assert_equal 180, stat.points_scored
    assert_equal 180.0, stat.three_dart_average
    assert_equal 180, stat.highest_turn
    assert_equal 1, stat.ton_plus
    assert_equal 1, stat.one_forty_plus
    assert_equal 1, stat.one_eighty
  end

  test "group generator creates all round robin matches inside each group" do
    tournament = Tournament.create!(
      title: "Round Robin Core",
      format_type: "groups",
      best_of_legs: 1,
      best_of_sets: 1,
      group_count: 2,
      seeding_mode: "manual"
    )
    6.times { |i| tournament.entries.create!(name: "Player #{i + 1}", seed: i + 1) }

    TournamentGenerator.new(tournament).call

    assert_equal 2, tournament.rounds.where(stage_type: "groups").count
    assert_equal 6, tournament.tournament_matches.count
    tournament.rounds.where(stage_type: "groups").find_each do |round|
      assert_equal 3, round.tournament_matches.count
      round.tournament_matches.each do |match|
        assert_equal round.group_name, match.home_entry.group_name
        assert_equal round.group_name, match.away_entry.group_name
      end
    end
  end

  test "completed groups generate playoff ladder once and cross pair first round" do
    tournament = Tournament.create!(
      title: "Groups To Playoffs Core",
      format_type: "groups",
      best_of_legs: 1,
      best_of_sets: 1,
      group_count: 2,
      qualifiers_per_group: 2,
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

    3.times { TournamentProgressor.new(tournament).call }

    playoff_rounds = tournament.rounds.where(stage_type: "playoffs")
    assert_equal 1, playoff_rounds.count
    matches = playoff_rounds.first.tournament_matches.order(:position)
    assert_equal 2, matches.count
    matches.each do |match|
      refute_equal match.home_entry.group_name, match.away_entry.group_name
    end
  end

  test "linked match completion syncs tournament match and standings" do
    tournament = Tournament.create!(title: "Linked Core", format_type: "groups", best_of_legs: 1, best_of_sets: 1, starting_score: 101, double_out: false)
    home = tournament.entries.create!(name: "Alpha", seed: 1, group_name: "A")
    away = tournament.entries.create!(name: "Bravo", seed: 2, group_name: "A")
    round = tournament.rounds.create!(number: 1, name: "Group A", stage_type: "groups", group_name: "A", status: "active")
    tournament_match = round.tournament_matches.create!(tournament: tournament, home_entry: home, away_entry: away, position: 1, best_of_legs: 1, best_of_sets: 1, starting_score: 101, double_out: false)
    linked_match = MatchCreator.call(
      settings: MatchSettings.from_tournament_match(tournament_match),
      players: [ { name: home.name }, { name: away.name } ],
      guest_match: true
    )
    tournament_match.update!(linked_match: linked_match, status: "live")

    turn = linked_match.current_leg.current_turn
    turn.leg.leg_players.find_by!(player: turn.player).update!(score: 60)
    turn.distribute_total!(60)

    tournament_match.reload
    assert_equal "complete", tournament_match.status
    assert_equal home, tournament_match.winner_entry
    assert_equal 1, tournament_match.home_legs
    assert_equal 1, home.reload.wins
    assert_equal 1, home.points
    assert_equal 1, away.reload.losses
  end
end
