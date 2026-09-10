require "test_helper"

class DartSetupStatsPerformanceTest < ActiveSupport::TestCase
  setup do
    skip "Set RUN_PERFORMANCE_TESTS=1 to run performance tests" unless ENV["RUN_PERFORMANCE_TESTS"] == "1"
  end

  test "query count remains bounded as tracked match history grows" do
    small_user = create_premium_user_with_history("small-setup-history@example.com", match_count: 1)
    large_user = create_premium_user_with_history("large-setup-history@example.com", match_count: 8)

    small = measure_grouped(small_user)
    large = measure_grouped(large_user)

    puts "DartSetupStats 1 match: #{small[:elapsed].round(4)}s, #{small[:queries]} queries"
    puts "DartSetupStats 8 matches: #{large[:elapsed].round(4)}s, #{large[:queries]} queries"

    assert_equal small[:queries], large[:queries]
    assert_operator large[:elapsed], :<, 3.0
  end

  private

  def create_premium_user_with_history(email, match_count:)
    user = create_user(email)
    user.update!(account_tier: "premium")
    setup = user.create_dart_setup!(
      manufacturer: "target",
      weight_g: 24.0,
      shaft_type: "carbon",
      shaft_length_mm: 42,
      point_length_mm: 35
    )

    match_count.times { create_dense_match(user, setup) }
    user
  end

  def create_dense_match(user, setup)
    match = Match.create!(starting_score: 501, best_of_legs: 5)
    player = match.players.build(name: "Setup Owner", user: user)
    player.assign_dart_setup_snapshot!(setup)
    player.save!
    opponent = match.players.create!(name: "Opponent")
    match_set = match.match_sets.create!

    3.times do |leg_index|
      leg = match_set.legs.create!(
        match:,
        winner_id: leg_index.even? ? player.id : opponent.id,
        finished_at: Time.current,
        checkout_throws: 3
      )
      12.times do |turn_index|
        turn_player = turn_index.even? ? player : opponent
        turn = leg.turns.create!(player: turn_player, completed_at: Time.current, total_score: 60)
        3.times { turn.throws.create!(segment: 20, multiplier: :single) }
      end
    end
  end

  def measure_grouped(user)
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
        DartSetupStats.new(user: user).grouped
        elapsed = Process.clock_gettime(Process::CLOCK_MONOTONIC) - started
      end
    end

    { elapsed:, queries: }
  end
end
