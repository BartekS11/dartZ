# frozen_string_literal: true

require "e2e_helper"

class BotGameplayFlowTest < E2EIntegrationTest
  test "bot levels are reduced to one through ten and controller clamps old high values" do
    user = create_user(unique_email("bot-clamp"))
    login_as(user)

    post bot_match_path, params: {
      player_name: "Human",
      bot_name: "Old Level Bot",
      bot_level: 20,
      starting_score: 501,
      best_of_legs: 1,
      best_of_sets: 1,
      double_out: "1"
    }

    match = Match.order(:created_at).last
    assert_redirected_to match_path(match)
    assert_equal 10, match.players.find_by!(bot: true).bot_level
  end

  test "higher bot level produces stronger scoring distribution than rookie level" do
    srand 20240830
    rookie_average = average_bot_turn_total(level: 1, score: 501, samples: 300)

    srand 20240830
    pro_average = average_bot_turn_total(level: 10, score: 501, samples: 300)

    assert_operator pro_average, :>, rookie_average + 15
  end

  test "strong bot attempts checkout route more often under pressure" do
    srand 20240831
    rookie_checkout_starts = checkout_route_starts(level: 1, score: 121, samples: 200)

    srand 20240831
    pro_checkout_starts = checkout_route_starts(level: 10, score: 121, samples: 200)

    assert_operator pro_checkout_starts, :>, rookie_checkout_starts
  end

  test "bot job performs bot turn without configured sleeps and writes legal throws" do
    user = create_user(unique_email("bot-job"))
    login_as(user)

    post bot_match_path, params: {
      player_name: "Human",
      bot_name: "Job Bot",
      bot_level: 10,
      starting_score: 101,
      best_of_legs: 1,
      best_of_sets: 1,
      double_out: "1"
    }

    match = Match.order(:created_at).last
    bot = match.players.find_by!(bot: true)
    human_turn = match.current_leg.current_turn
    submit_turn_total(human_turn, 0)
    assert_response :redirect

    bot_turn = match.reload.current_leg.current_turn
    assert_equal bot, bot_turn.player

    assert_changes -> { bot_turn.reload.throws.count }, from: 0 do
      BotTurnJob.perform_now(bot_turn.id)
    end

    assert bot_turn.reload.completed? || match.reload.finished?
    assert bot_turn.throws.all? { |throw| throw.segment.between?(0, 25) }
  end

  private

  def average_bot_turn_total(level:, score:, samples:)
    samples.times.sum do
      BotService.play_turn(score: score, level: level).fetch("throws").sum do |throw_name|
        BotService::THROW_VALUES.fetch(throw_name)
      end
    end / samples.to_f
  end

  def checkout_route_starts(level:, score:, samples:)
    checkout_first = CheckoutCalculator.suggest(score, darts_remaining: 3).first
    samples.times.count do
      BotService.play_turn(score: score, level: level).fetch("throws").first == checkout_first
    end
  end
end
