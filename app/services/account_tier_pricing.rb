class AccountTierPricing
  MONTHLY_AMOUNTS = {
    "usd" => { premium: 499, pro: 999 },
    "pln" => { premium: 1_999, pro: 3_999 }
  }.freeze

  def initialize(currency:)
    @currency = currency.to_s.downcase
  end

  def prices(interval: "month")
    { free: free_label, premium: price_label(:premium, interval), pro: price_label(:pro, interval) }
  end

  def amount_for(tier, interval: "month")
    monthly_amount = MONTHLY_AMOUNTS.fetch(currency).fetch(tier.to_sym)
    interval.to_s == "year" ? (monthly_amount * 12 * 75) / 100 : monthly_amount
  end

  def price_label(tier, interval = "month")
    amount = amount_for(tier, interval: interval)
    if currency == "pln"
      whole, fractional = amount.divmod(100)
      "#{whole},#{format('%02d', fractional)} zł"
    else
      "$#{format('%.2f', amount / 100.0)}"
    end
  end

  private

  attr_reader :currency

  def free_label
    currency == "pln" ? "0 zł" : "$0"
  end
end
