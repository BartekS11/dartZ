class BillingController < ApplicationController
  SUPPORTED_PAID_TIERS = %w[premium pro].freeze
  SUPPORTED_INTERVALS = %w[month year].freeze

  def show
    flash.now[:notice] = t("billing.checkout_success") if params[:stripe_checkout] == "success"
    flash.now[:alert] = t("billing.checkout_cancelled") if params[:stripe_checkout] == "cancelled"
    @billing_currency = billing_currency
    @billing_interval = SUPPORTED_INTERVALS.include?(params[:billing_interval]) ? params[:billing_interval] : "month"
    @tiers = AccountTierCatalog.new(
      prices: AccountTierPricing.new(currency: @billing_currency).prices(interval: @billing_interval),
      interval: @billing_interval
    ).tiers
  end

  def checkout
    tier = params[:tier].to_s
    interval = params[:interval].to_s
    return redirect_to billing_path, alert: t("billing.invalid_tier") unless SUPPORTED_PAID_TIERS.include?(tier)
    return redirect_to billing_path, alert: t("billing.invalid_interval") unless SUPPORTED_INTERVALS.include?(interval)

    return redirect_to billing_path, alert: t("billing.missing_stripe_config") if Stripe.api_key.blank?

    if Current.user.subscribed?
      if interval == "year" && Current.user.account_tier == tier
        result = schedule_yearly_change!(tier: tier)
        message = { scheduled: "yearly_change_scheduled", already_yearly: "already_yearly", already_scheduled: "yearly_change_already_scheduled" }.fetch(result)
        return redirect_to billing_path, notice: t("billing.#{message}")
      end
      return redirect_to billing_path, alert: t("billing.active_subscription")
    end

    currency = billing_currency
    pricing = AccountTierPricing.new(currency: currency)
    line_item = if interval == "year"
      {
        price_data: {
          currency: currency,
          unit_amount: pricing.amount_for(tier, interval: interval),
          recurring: { interval: "year" },
          product_data: { name: I18n.t("billing.#{tier}_name") }
        },
        quantity: 1
      }
    else
      price_id = StripeBilling::Configuration.price_id_for(tier: tier, currency: currency)
      return redirect_to billing_path, alert: t("billing.missing_stripe_config") if price_id.blank?
      { price: price_id, quantity: 1 }
    end
    customer_id = ensure_stripe_customer!
    session = Stripe::Checkout::Session.create(
      mode: "subscription",
      customer: customer_id,
      line_items: [ line_item ],
      success_url: billing_url(stripe_checkout: "success"),
      cancel_url: billing_url(stripe_checkout: "cancelled"),
      client_reference_id: Current.user.id,
      metadata: { user_id: Current.user.id, tier: tier, currency: currency, interval: interval },
      subscription_data: { metadata: { user_id: Current.user.id, tier: tier, currency: currency, interval: interval } }
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

  def schedule_yearly_change!(tier:)
    return if Stripe.api_key.blank?

    subscription = Stripe::Subscription.retrieve(Current.user.stripe_subscription_id)
    return :already_scheduled if subscription.respond_to?(:schedule) && subscription.schedule.present?

    item = subscription.items.data.first
    raise Stripe::StripeError, "Subscription price unavailable" unless item&.price&.recurring
    return :already_yearly if item.price.recurring.interval == "year"
    raise Stripe::StripeError, "Multiple subscription items are not supported" unless subscription.items.data.one?

    currency = item.price.currency
    pricing = AccountTierPricing.new(currency: currency)
    annual_price = Stripe::Price.create(
      currency: currency,
      unit_amount: pricing.amount_for(tier, interval: "year"),
      recurring: { interval: "year" },
      product: item.price.product
    )
    schedule = Stripe::SubscriptionSchedule.create(from_subscription: subscription.id)
    period_end = subscription.current_period_end
    current_phase = {
      start_date: subscription.current_period_start,
      end_date: period_end,
      items: subscription.items.data.map { |subscription_item| { price: subscription_item.price.id, quantity: subscription_item.quantity || 1 } }
    }
    Stripe::SubscriptionSchedule.update(
      schedule.id,
      end_behavior: "release",
      phases: [
        current_phase,
        { start_date: period_end, iterations: 1, items: [ { price: annual_price.id, quantity: 1 } ], proration_behavior: "none" }
      ]
    )
    :scheduled
  end

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
