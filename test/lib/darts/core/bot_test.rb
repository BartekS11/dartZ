require "minitest/autorun"
require_relative "../../../../lib/darts/core"

class DartsCoreBotTest < Minitest::Test
  def test_plays_a_legal_length_turn
    result = Darts::Core::Bot.play_turn(score: 301, level: 10)

    assert_kind_of Hash, result
    assert_kind_of Array, result["throws"]
    assert result["throws"].size <= 3
    assert result.key?("remaining")
  end

  def test_each_level_has_distinct_scoring_and_finishing
    scoring = []
    finishing = []
    (1..10).each do |level|
      srand 1234
      scoring << 8_000.times.sum do
        Darts::Core::Bot.play_turn(score: 501, level: level).fetch("throws").sum do |name|
          Darts::Core::Bot::THROW_VALUES.fetch(name)
        end
      end / 8_000.0
      srand 5678
      finishing << 8_000.times.count do
        Darts::Core::Bot.play_turn(score: 40, level: level).fetch("remaining").zero?
      end / 8_000.0
    end
    scoring.each_cons(2) { |lower, higher| assert_operator higher - lower, :>, 3.0 }
    finishing.each_cons(2) { |lower, higher| assert_operator higher - lower, :>, 0.02 }
    assert_includes 20..30, scoring.first
    assert_includes 80..95, scoring.last
    assert_includes 0.45..0.75, finishing.last
  ensure
    srand
  end

  def test_accuracy_and_decision_quality_increase_at_every_level
    bot = Darts::Core::Bot
    %i[single triple double bull].each do |ring|
      [false, true].each do |pressure|
        probabilities = (1..10).map { |level| bot.send(:hit_probability, ring, level, pressure: pressure) }
        probabilities.each_cons(2) { |lower, higher| assert_operator higher, :>, lower }
      end
    end
    route_rates = (1..10).map do |level|
      srand 4321
      4_000.times.count { bot.send(:attempt_checkout_route?, level, 100) } / 4_000.0
    end
    route_rates.each_cons(2) { |lower, higher| assert_operator higher - lower, :>, 0.06 }
    (1..10).each do |level|
      assert bot.send(:attempt_checkout_route?, level, 40)
      assert bot.send(:attempt_checkout_route?, level, 50)
    end
  ensure
    srand
  end

  def test_all_levels_return_legal_throws_across_rule_variants
    srand 2468
    (1..10).each do |level|
      [2, 3, 25, 40, 50, 61, 99, 170, 301, 501].each do |score|
        [false, true].product([false, true]).each do |double_in, double_out|
          result = Darts::Core::Bot.play_turn(score: score, level: level,
            double_in: double_in, double_out: double_out, has_doubled_in: false)
          assert_includes 1..3, result.fetch("throws").size
          result.fetch("throws").each { |name| assert Darts::Core::Bot::THROW_VALUES.key?(name) }
        end
      end
    end
  ensure
    srand
  end

  def test_converts_bot_throw_names_to_attributes_through_core_throw
    assert_equal({ segment: 20, multiplier: "triple" }, Darts::Core::Bot.throw_to_attributes("T20"))
    assert_equal({ segment: 0, multiplier: "miss" }, Darts::Core::Bot.throw_to_attributes("MISS"))
  end
end
