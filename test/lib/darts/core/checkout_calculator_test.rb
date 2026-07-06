require "minitest/autorun"
require_relative "../../../../lib/darts/core"

class DartsCoreCheckoutCalculatorTest < Minitest::Test
  def test_suggests_canonical_double_out_checkouts
    assert_equal [ "T20", "T20", "Bull" ], Darts::Core::CheckoutCalculator.suggest(170)
    assert_equal [ "D20" ], Darts::Core::CheckoutCalculator.suggest(40)
  end

  def test_returns_nil_for_impossible_checkouts
    [ 1, 169, 171 ].each do |score|
      assert_nil Darts::Core::CheckoutCalculator.suggest(score)
    end
  end

  def test_calculates_darts_needed_for_double_out_and_straight_out
    assert_equal 3, Darts::Core::CheckoutCalculator.darts_needed(141)
    assert_equal 1, Darts::Core::CheckoutCalculator.darts_needed(40)
    assert_equal 2, Darts::Core::CheckoutCalculator.darts_needed(61, double_out: false)
  end
end
