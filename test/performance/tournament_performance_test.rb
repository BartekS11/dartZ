require "test_helper"

class TournamentPerformanceTest < ActiveSupport::TestCase
  setup do
    skip "Set RUN_PERFORMANCE_TESTS=1 to run performance tests" unless ENV["RUN_PERFORMANCE_TESTS"] == "1"
  end

  test "swiss generation stays within a reasonable bound for 32 entrants" do
    tournament = Tournament.create!(
      title: "Swiss Perf",
      format_type: "swiss",
      best_of_legs: 3,
      best_of_sets: 1,
      swiss_round_count: 5,
      seeding_mode: "manual"
    )

    32.times do |i|
      tournament.entries.create!(name: "Player #{i + 1}", seed: i + 1)
    end

    elapsed = measure_time do
      TournamentGenerator.new(tournament).call

      3.times do
        round = tournament.reload.swiss_rounds.order(:number).last
        round.tournament_matches.where(bye: false).order(:position).each_with_index do |match, idx|
          winner = idx.even? ? match.home_entry : match.away_entry
          home_legs = winner == match.home_entry ? 3 : 1
          away_legs = winner == match.away_entry ? 3 : 1
          match.update!(winner_entry: winner, home_legs:, away_legs:, status: "complete", completed_at: Time.current)
        end
        TournamentProgressor.new(tournament).call
      end
    end

    puts "Swiss generation/progression (32 entrants, 4 rounds total): #{elapsed.round(3)}s"
    assert_operator elapsed, :<, 4.0
  end

  test "playoff progression stays within a reasonable bound for 16 entrants" do
    tournament = Tournament.create!(
      title: "Playoff Perf",
      format_type: "playoffs",
      best_of_legs: 3,
      best_of_sets: 1,
      seeding_mode: "manual",
      playoff_mode: "single_elimination",
      bronze_match: true
    )

    16.times do |i|
      tournament.entries.create!(name: "Seed #{i + 1}", seed: i + 1)
    end

    elapsed = measure_time do
      TournamentGenerator.new(tournament).call

      while tournament.reload.status != "complete"
        tournament.rounds.where(stage_type: "playoffs", status: "active").order(:number).each do |round|
          round.tournament_matches.order(:position).each do |match|
            next if match.status == "complete"

            match.update!(winner_entry: match.home_entry, home_legs: 3, away_legs: 1, status: "complete", completed_at: Time.current)
          end
        end

        TournamentProgressor.new(tournament).call
      end
    end

    puts "Playoff progression (16 entrants): #{elapsed.round(3)}s"
    assert_operator elapsed, :<, 4.0
  end

  private

  def measure_time
    started = Process.clock_gettime(Process::CLOCK_MONOTONIC)
    yield
    Process.clock_gettime(Process::CLOCK_MONOTONIC) - started
  end
end
