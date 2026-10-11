class AccountTierPricing
  MONTHLY_AMOUNTS = {
    "usd" => { premium: 499, pro: 999 },
    "gbp" => { premium: 399, pro: 799 },
    "pln" => { premium: 999, pro: 1_999 }
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
    format_amount(amount_for(tier, interval: interval))
  end

  def undiscounted_year_price_label(tier)
    format_amount(amount_for(tier) * 12)
  end

  private

  attr_reader :currency

  def free_label
    currency == "pln" ? "0 zł" : (currency == "gbp" ? "£0" : "$0")
  end

  def format_amount(amount)
    if currency == "pln"
      whole, fractional = amount.divmod(100)
      "#{whole},#{format('%02d', fractional)} zł"
    else
      symbol = currency == "gbp" ? "£" : "$"
      "#{symbol}#{format('%.2f', amount / 100.0)}"
    end
  end
end
