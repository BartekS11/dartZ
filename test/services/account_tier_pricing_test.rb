require "test_helper"

class AccountTierPricingTest < ActiveSupport::TestCase
  test "annual prices discount twelve monthly payments by 25 percent and floor minor units" do
    usd = AccountTierPricing.new(currency: "usd")
    pln = AccountTierPricing.new(currency: "pln")

    assert_equal 4_491, usd.amount_for(:premium, interval: "year")
    assert_equal 8_991, usd.amount_for(:pro, interval: "year")
    assert_equal 17_991, pln.amount_for(:premium, interval: "year")
    assert_equal 35_991, pln.amount_for(:pro, interval: "year")
    assert_equal "$44.91", usd.price_label(:premium, "year")
    assert_equal "179,91 zł", pln.price_label(:premium, "year")
  end
end
