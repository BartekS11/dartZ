require "test_helper"

class AdvancedMatchStatsPerformanceTest < ActiveSupport::TestCase
  setup do
    skip "Set RUN_PERFORMANCE_TESTS=1 to run performance tests" unless ENV["RUN_PERFORMANCE_TESTS"] == "1"
  end

  test "advanced metric query count remains bounded as history grows" do
    small_user = create_history("advanced-performance-small@example.com", match_count: 1)
    large_user = create_history("advanced-performance-large@example.com", match_count: 25)

    small = measure(small_user)
    large = measure(large_user)

    puts "AdvancedMatchStats 1 match: #{small[:elapsed].round(4)}s, #{small[:queries]} queries"
    puts "AdvancedMatchStats 25 matches: #{large[:elapsed].round(4)}s, #{large[:queries]} queries"

    assert_operator small[:queries], :<=, 15
    assert_equal small[:queries], large[:queries]
    assert_operator large[:elapsed], :<, 3.0
  end

  private

  def create_history(email, match_count:)
    user = create_user(email)
    user.update!(account_tier: "premium")

    match_count.times do
      match = Match.create!(starting_score: 501)
      player = match.players.create!(name: "Owner", user: user)
      match.players.create!(name: "Opponent")
      match_set = match.match_sets.create!
      leg = match_set.legs.create!(match: match)
      3.times do
        turn = leg.turns.create!(player: player, completed_at: Time.current, total_score: 60)
        3.times { turn.throws.create!(segment: 20, multiplier: :single) }
      end
    end

    user
  end

  def measure(user)
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
        dashboard = AdvancedMatchStats.new(user: user)
        dashboard.summary
        dashboard.trends
        dashboard.distribution
        dashboard.checkouts
        dashboard.head_to_head
        dashboard.leg_performance
        dashboard.set_performance
        dashboard.coverage
        elapsed = Process.clock_gettime(Process::CLOCK_MONOTONIC) - started
      end
    end

    { elapsed:, queries: }
  end
end
