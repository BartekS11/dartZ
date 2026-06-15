require "test_helper"

class MatchStatePresenterPerformanceTest < ActiveSupport::TestCase
  setup do
    skip "Set RUN_PERFORMANCE_TESTS=1 to run performance tests" unless ENV["RUN_PERFORMANCE_TESTS"] == "1"
  end

  test "match state presenter handles dense historical match data within a reasonable bound" do
    match = Match.create!(best_of_legs: 5, best_of_sets: 3)
    player_one = match.players.create!(name: "Alpha")
    player_two = match.players.create!(name: "Bravo")
    match_set = match.match_sets.create!

    6.times do |leg_index|
      leg = match_set.legs.create!(match: match, finished_at: Time.current, winner_id: leg_index.even? ? player_one.id : player_two.id)
      20.times do |turn_index|
        player = turn_index.even? ? player_one : player_two
        turn = leg.turns.create!(player:, completed_at: Time.current, total_score: 60)
        3.times do
          turn.throws.create!(segment: 20, multiplier: :single)
        end
      end
      leg.leg_players.find_by!(player: player_one).update!(score: 301)
      leg.leg_players.find_by!(player: player_two).update!(score: 241)
    end

    active_leg = match_set.legs.create!(match: match)
    active_turn = active_leg.turns.create!(player: player_one)
    active_turn.throws.create!(segment: 20, multiplier: :triple)
    active_leg.leg_players.find_by!(player: player_one).update!(score: 441)
    active_leg.leg_players.find_by!(player: player_two).update!(score: 501)

    loaded_match = Match.includes(players: :user, match_sets: [{ legs: [{ turns: :throws }, { leg_players: :player }] }]).find(match.id)

    elapsed = measure_time do
      presenter = MatchStatePresenter.new(loaded_match)
      presenter.summary_payload
      presenter.state_payload
      presenter.players.each do |player|
        presenter.stats_for(player)
        presenter.last_turn_throws_for(player)
      end
    end

    puts "MatchStatePresenter dense payload build: #{elapsed.round(3)}s"
    assert_operator elapsed, :<, 3.0
  end

  private

  def measure_time
    started = Process.clock_gettime(Process::CLOCK_MONOTONIC)
    yield
    Process.clock_gettime(Process::CLOCK_MONOTONIC) - started
  end
end
