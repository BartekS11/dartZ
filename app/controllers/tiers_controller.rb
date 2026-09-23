class TiersController < ApplicationController
  allow_unauthenticated_access
  before_action :resume_session_optional

  def show
    redirect_to billing_path and return if Current.user

    @billing_currency = billing_currency
    @tiers = AccountTierCatalog.new(prices: AccountTierPricing.new(currency: @billing_currency).prices).tiers
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
