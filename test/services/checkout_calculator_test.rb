require "test_helper"

class CheckoutCalculatorTest < ActiveSupport::TestCase
  test "checkout dart possibilities grey impossible one dart finishes" do
    refute CheckoutCalculator.possible_checkout_darts?(141, 1)
    refute CheckoutCalculator.possible_checkout_darts?(141, 2)
    assert CheckoutCalculator.possible_checkout_darts?(141, 3)
  end

  test "shorter checkout can still be recorded with extra missed darts" do
    assert CheckoutCalculator.possible_checkout_darts?(40, 1)
    assert CheckoutCalculator.possible_checkout_darts?(40, 2)
    assert CheckoutCalculator.possible_checkout_darts?(40, 3)
  end

  test "78 checkout prefers tops route" do
    assert_equal [ "T20", "D9" ], CheckoutCalculator.suggest(78, darts_remaining: 2)
  end

  test "impossible checkout score has no possible dart count" do
    [ 1, 169, 171 ].each do |score|
      refute CheckoutCalculator.possible_checkout_darts?(score, 1)
      refute CheckoutCalculator.possible_checkout_darts?(score, 2)
      refute CheckoutCalculator.possible_checkout_darts?(score, 3)
    end
  end
end
