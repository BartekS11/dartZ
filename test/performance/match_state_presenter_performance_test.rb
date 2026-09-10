require "test_helper"

class MatchStatePresenterPerformanceTest < ActiveSupport::TestCase
  ITERATIONS = 5

  setup do
    skip "Set RUN_PERFORMANCE_TESTS=1 to run performance tests" unless ENV["RUN_PERFORMANCE_TESTS"] == "1"

    @match = Match.create!(best_of_legs: 5, best_of_sets: 3)
    player_one = @match.players.create!(name: "Alpha")
    player_two = @match.players.create!(name: "Bravo")
    match_set = @match.match_sets.create!

    6.times do |leg_index|
      leg = match_set.legs.create!(match: @match, finished_at: Time.current, winner_id: leg_index.even? ? player_one.id : player_two.id)
      20.times do |turn_index|
        player = turn_index.even? ? player_one : player_two
        turn = leg.turns.create!(player:, completed_at: Time.current, total_score: 60)
        3.times { turn.throws.create!(segment: 20, multiplier: :single) }
      end
      leg.leg_players.find_by!(player: player_one).update!(score: 301)
      leg.leg_players.find_by!(player: player_two).update!(score: 241)
    end

    active_leg = match_set.legs.create!(match: @match)
    active_turn = active_leg.turns.create!(player: player_one)
    active_turn.throws.create!(segment: 20, multiplier: :triple)
    active_leg.leg_players.find_by!(player: player_one).update!(score: 441)
    active_leg.leg_players.find_by!(player: player_two).update!(score: 501)
  end

  test "summary state and detailed paths report separate elapsed times and query counts" do
    measurements = {
      summary: measure_repeated { |presenter| presenter.summary_payload },
      state: measure_repeated { |presenter| presenter.state_payload },
      detailed: measure_repeated { |presenter| presenter.players.each { |player| presenter.stats_for(player) } }
    }

    measurements.each do |path, result|
      puts "MatchStatePresenter #{path}: median #{result[:median].round(4)}s, queries #{result[:queries].inspect}"
      assert_operator result[:median], :<, 3.0
      assert_operator result[:queries].max, :<=, 7
    end
  end

  private

  def measure_repeated(&block)
    results = Array.new(ITERATIONS) { measure_path(&block) }
    elapsed = results.pluck(:elapsed).sort

    {
      median: elapsed.fetch(elapsed.length / 2),
      queries: results.pluck(:queries).uniq.sort
    }
  end

  def measure_path
    loaded_match = Match.includes(
      players: :user,
      match_sets: [ { legs: [ { turns: :throws }, { leg_players: :player } ] } ]
    ).find(@match.id)

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
        presenter = MatchStatePresenter.new(loaded_match)
        yield presenter
        elapsed = Process.clock_gettime(Process::CLOCK_MONOTONIC) - started
      end
    end

    { elapsed:, queries: }
  end
end
