class TiersController < ApplicationController
  allow_unauthenticated_access
  before_action :resume_session_optional

  def show
    redirect_to billing_path and return if Current.user

    @billing_currency = billing_currency
    @billing_interval = %w[month year].include?(params[:billing_interval]) ? params[:billing_interval] : "month"
    pricing = AccountTierPricing.new(currency: @billing_currency)
    @tiers = AccountTierCatalog.new(prices: pricing.prices(interval: @billing_interval), interval: @billing_interval).tiers
    @regular_year_prices = %i[premium pro].index_with { |tier| pricing.undiscounted_year_price_label(tier) }
  end

  private

  def billing_currency
    polish_country? ? "pln" : "usd"
  end

  def polish_country?
    country = request.headers["CF-IPCountry"].presence || request.headers["X-Country-Code"].presence
    country.to_s.casecmp("PL").zero? || I18n.locale.to_s == "pl"
  end
end
