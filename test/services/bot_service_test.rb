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

  test "can produce checkout-safe finish attempts" do
    original = BotService.method(:resolve_throw)
    BotService.define_singleton_method(:resolve_throw) { |_target, _level| "D20" }

    result = BotService.play_turn(score: 40, level: 20)

    assert_equal [ "D20" ], result["throws"]
    assert_equal 0, result["remaining"]
  ensure
    BotService.define_singleton_method(:resolve_throw, original)
  end
end
