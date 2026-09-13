require "test_helper"

class MatchStatsDashboardBaselineTest < ActiveSupport::TestCase
  setup do
    skip "Set RUN_PERFORMANCE_TESTS=1 to record the stats baseline" unless ENV["RUN_PERFORMANCE_TESTS"] == "1"
  end

  test "records current dashboard time and query growth" do
    small_user = create_user_with_history("stats-baseline-small@example.com", match_count: 1)
    large_user = create_user_with_history("stats-baseline-large@example.com", match_count: 8)

    small = measure_dashboard(small_user)
    large = measure_dashboard(large_user)

    puts "MatchStatsDashboard 1 match: #{small[:elapsed].round(4)}s, #{small[:queries]} queries"
    puts "MatchStatsDashboard 8 matches: #{large[:elapsed].round(4)}s, #{large[:queries]} queries"

    assert_operator small[:elapsed], :<, 5.0
    assert_operator large[:elapsed], :<, 5.0
    assert_predicate small[:queries], :positive?
    assert_operator large[:queries], :>=, small[:queries]
  end

  private

  def create_user_with_history(email, match_count:)
    user = create_user(email)

    match_count.times do |match_index|
      match = Match.create!(starting_score: 501, best_of_legs: 3, best_of_sets: 1)
      player = match.players.create!(name: "Stats Owner #{match_index}", user: user)
      opponent = match.players.create!(name: "Opponent #{match_index}")
      match.start_first_set!(player)
      leg = match.current_leg

      3.times do
        turn = leg.turns.create!(player: player, completed_at: Time.current, total_score: 60)
        3.times { turn.throws.create!(segment: 20, multiplier: :single) }
      end

      opponent_turn = leg.turns.create!(player: opponent, completed_at: Time.current, total_score: 45)
      3.times { opponent_turn.throws.create!(segment: 15, multiplier: :single) }
    end

    user
  end

  def measure_dashboard(user)
    queries = 0
    subscriber = lambda do |_name, _started, _finished, _unique_id, payload|
      next if payload[:cached]
      next if payload[:name].to_s.match?(/SCHEMA|TRANSACTION/)
      next if payload[:sql].to_s.match?(/\A(?:BEGIN|COMMIT|ROLLBACK|SAVEPOINT|RELEASE)/)

      queries += 1
    end

    elapsed = nil
    ActiveRecord::Base.uncached do
      ActiveSupport::Notifications.subscribed(subscriber, "sql.active_record") do
        started = Process.clock_gettime(Process::CLOCK_MONOTONIC)
        dashboard = MatchStatsDashboard.new(user: user)
        dashboard.summary
        dashboard.chart_data
        dashboard.opponents
        dashboard.dart_setups
        elapsed = Process.clock_gettime(Process::CLOCK_MONOTONIC) - started
      end
    end

    { elapsed:, queries: }
  end
end
