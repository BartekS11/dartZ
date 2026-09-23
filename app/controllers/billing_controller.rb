class BillingController < ApplicationController
  SUPPORTED_PAID_TIERS = %w[premium pro].freeze

  def show
    flash.now[:notice] = t("billing.checkout_success") if params[:stripe_checkout] == "success"
    flash.now[:alert] = t("billing.checkout_cancelled") if params[:stripe_checkout] == "cancelled"
    @billing_currency = billing_currency
    @tiers = AccountTierCatalog.new(prices: AccountTierPricing.new(currency: @billing_currency).prices).tiers
  end

  def checkout
    tier = params[:tier].to_s
    return redirect_to billing_path, alert: t("billing.invalid_tier") unless SUPPORTED_PAID_TIERS.include?(tier)
    return redirect_to billing_path, alert: t("billing.active_subscription") if Current.user.subscribed?

    currency = billing_currency
    price_id = StripeBilling::Configuration.price_id_for(tier: tier, currency: currency)
    return redirect_to billing_path, alert: t("billing.missing_stripe_config") if Stripe.api_key.blank? || price_id.blank?

    customer_id = ensure_stripe_customer!
    session = Stripe::Checkout::Session.create(
      mode: "subscription",
      customer: customer_id,
      line_items: [ { price: price_id, quantity: 1 } ],
      success_url: billing_url(stripe_checkout: "success"),
      cancel_url: billing_url(stripe_checkout: "cancelled"),
      client_reference_id: Current.user.id,
      metadata: { user_id: Current.user.id, tier: tier, currency: currency },
      subscription_data: { metadata: { user_id: Current.user.id, tier: tier, currency: currency } }
    )

    redirect_to session.url, allow_other_host: true
  rescue Stripe::StripeError => e
    Rails.logger.warn("Stripe checkout failed for user #{Current.user.id}: #{e.class}: #{e.message}")
    redirect_to billing_path, alert: t("billing.stripe_error")
  end

  def portal
    return redirect_to billing_path, alert: t("billing.no_subscription") if Current.user.stripe_customer_id.blank?
    return redirect_to billing_path, alert: t("billing.missing_stripe_config") if Stripe.api_key.blank?

    session = Stripe::BillingPortal::Session.create(
      customer: Current.user.stripe_customer_id,
      return_url: billing_url
    )

    redirect_to session.url, allow_other_host: true
  rescue Stripe::StripeError => e
    Rails.logger.warn("Stripe portal failed for user #{Current.user.id}: #{e.class}: #{e.message}")
    redirect_to billing_path, alert: t("billing.stripe_error")
  end

  private

  def ensure_stripe_customer!
    return Current.user.stripe_customer_id if Current.user.stripe_customer_id.present?

    customer = Stripe::Customer.create(
      email: Current.user.email_address,
      metadata: { user_id: Current.user.id }
    )
    Current.user.update!(stripe_customer_id: customer.id)
    customer.id
  end

  def billing_currency
    polish_country? ? "pln" : "usd"
  end
  helper_method :billing_currency

  def polish_country?
    country = request.headers["CF-IPCountry"].presence || request.headers["X-Country-Code"].presence
    country.to_s.casecmp("PL").zero? || I18n.locale.to_s == "pl"
  end
end
