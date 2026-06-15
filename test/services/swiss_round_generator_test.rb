require "test_helper"

class SwissRoundGeneratorTest < ActiveSupport::TestCase
  test "creates next swiss round without rematches when possible" do
    tournament = Tournament.create!(
      title: "Swiss Open",
      format_type: "swiss",
      best_of_legs: 3,
      best_of_sets: 1,
      swiss_round_count: 3,
      seeding_mode: "manual"
    )

    6.times do |i|
      tournament.entries.create!(name: "Player #{i + 1}", seed: i + 1)
    end

    TournamentGenerator.new(tournament).call
    round_one = tournament.swiss_rounds.first
    round_one.tournament_matches.order(:position).each_with_index do |match, idx|
      winner = idx.even? ? match.home_entry : match.away_entry
      match.update!(winner_entry: winner, home_legs: winner == match.home_entry ? 3 : 1, away_legs: winner == match.away_entry ? 3 : 1, status: "complete", completed_at: Time.current)
    end

    TournamentProgressor.new(tournament).call

    round_two = tournament.reload.swiss_rounds.find_by(number: 2)
    assert_not_nil round_two

    first_round_pairs = round_one.tournament_matches.map { |m| [m.home_entry_id, m.away_entry_id].sort }
    second_round_pairs = round_two.tournament_matches.where.not(away_entry_id: nil).map { |m| [m.home_entry_id, m.away_entry_id].sort }

    second_round_pairs.each do |pair|
      assert_not_includes first_round_pairs, pair
    end
  end

  test "assigns byes to different players across swiss rounds when possible" do
    tournament = Tournament.create!(
      title: "Odd Swiss",
      format_type: "swiss",
      best_of_legs: 3,
      best_of_sets: 1,
      swiss_round_count: 3,
      seeding_mode: "manual"
    )

    5.times do |i|
      tournament.entries.create!(name: "Odd Player #{i + 1}", seed: i + 1)
    end

    TournamentGenerator.new(tournament).call
    bye_winners = []

    2.times do
      round = tournament.reload.swiss_rounds.order(:number).last
      bye_match = round.tournament_matches.find_by(bye: true)
      bye_winners << bye_match.winner_entry_id

      round.tournament_matches.where(bye: false).each do |match|
        match.update!(winner_entry: match.home_entry, home_legs: 3, away_legs: 1, status: "complete", completed_at: Time.current)
      end

      TournamentProgressor.new(tournament).call
    end

    assert_equal bye_winners.uniq.size, bye_winners.size
  end
end
