require "minitest/autorun"
require_relative "../../../../lib/darts/core"

class DartsCoreThrowTest < Minitest::Test
  def test_calculates_points_for_named_throws
    assert_equal 60, Darts::Core::Throw.from_name("T20").points
    assert_equal 40, Darts::Core::Throw.from_name("D20").points
    assert_equal 25, Darts::Core::Throw.from_name("25").points
    assert_equal 50, Darts::Core::Throw.from_name("Bull").points
    assert_equal 0, Darts::Core::Throw.from_name("MISS").points
  end

  def test_converts_throw_names_to_persistence_attributes
    assert_equal({ segment: 20, multiplier: "triple" }, Darts::Core::Throw.from_name("T20").to_attributes)
    assert_equal({ segment: 25, multiplier: "double" }, Darts::Core::Throw.from_name("Bull").to_attributes)
  end

  def test_rejects_invalid_board_segments
    assert_raises(ArgumentError) do
      Darts::Core::Throw.new(segment: 21, multiplier: "single")
    end
  end
end
