class AccountTierPricing
  def initialize(currency:)
    @currency = currency.to_s
  end

  def prices
    currency == "pln" ? pln_prices : usd_prices
  end

  private

  attr_reader :currency

  def usd_prices
    { free: "$0", premium: "$4.99", pro: "$9.99" }
  end

  def pln_prices
    { free: "0 zł", premium: "19,99 zł", pro: "39,99 zł" }
  end
end
