require "test_helper"

class BotServiceTest < ActiveSupport::TestCase
  test "returns throws and remaining score" do
    result = BotService.play_turn(score: 301, level: 10)

    assert_kind_of Hash, result
    assert_kind_of Array, result["throws"]
    assert result.key?("remaining")
    assert result["throws"].size <= 3
  end

  test "never returns invalid throw names" do
    valid = BotService::THROW_VALUES.keys

    20.times do
      result = BotService.play_turn(score: 170, level: 12)
      assert result["throws"].all? { |throw| valid.include?(throw) }
    end
  end

  test "clamps reduced numeric levels" do
    assert_equal 1, BotService.normalize_level(-5)
    assert_equal 5, BotService.normalize_level(5)
    assert_equal 10, BotService.normalize_level(99)
  end

  test "can produce checkout-safe finish attempts" do
    original = BotService.method(:resolve_throw)
    BotService.define_singleton_method(:resolve_throw) { |_target, _level, pressure: false| "D20" }

    result = BotService.play_turn(score: 40, level: 10)

    assert_equal [ "D20" ], result["throws"]
    assert_equal 0, result["remaining"]
  ensure
    BotService.define_singleton_method(:resolve_throw, original)
  end

  test "higher level produces stronger average scoring than rookie level" do
    srand 1234
    rookie_average = average_turn_total(level: 1)
    srand 1234
    pro_average = average_turn_total(level: 10)

    assert_operator pro_average, :>, rookie_average + 15
  end

  private

  def average_turn_total(level:)
    200.times.sum do
      result = BotService.play_turn(score: 501, level: level)
      result.fetch("throws").sum { |throw_name| BotService::THROW_VALUES.fetch(throw_name) }
    end / 200.0
  end
end
