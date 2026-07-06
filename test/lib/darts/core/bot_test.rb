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

  def test_converts_bot_throw_names_to_attributes_through_core_throw
    assert_equal({ segment: 20, multiplier: "triple" }, Darts::Core::Bot.throw_to_attributes("T20"))
    assert_equal({ segment: 0, multiplier: "miss" }, Darts::Core::Bot.throw_to_attributes("MISS"))
  end
end
