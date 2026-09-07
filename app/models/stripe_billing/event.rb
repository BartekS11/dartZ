class StripeBilling::Event
  def initialize(event)
    @event = event
  end

  def process
    case @event.type
    when "checkout.session.completed"
      sync_checkout_session(@event.data.object)
    when "customer.subscription.created", "customer.subscription.updated", "customer.subscription.deleted"
      sync_subscription(@event.data.object)
    when "invoice.payment_failed", "invoice.paid"
      sync_invoice(@event.data.object)
    else
      Rails.logger.info("Unhandled Stripe webhook event: #{@event.type}")
    end
  end

  private
    def sync_checkout_session(session)
      user = User.find(session.client_reference_id || session.metadata&.user_id)
      user.update!(stripe_customer_id: stripe_id(session.customer)) if session.customer.present?

      subscription = Stripe::Subscription.retrieve(stripe_id(session.subscription))
      sync_user_from_subscription(user, subscription, fallback_tier: session.metadata&.tier, fallback_currency: session.metadata&.currency)
    end

    def sync_subscription(subscription)
      user = user_for_subscription(subscription)
      sync_user_from_subscription(user, subscription) if user
    end

    def sync_invoice(invoice)
      subscription_id = stripe_id(invoice.subscription)
      return if subscription_id.blank?

      subscription = Stripe::Subscription.retrieve(subscription_id)
      user = user_for_subscription(subscription, subscription_id: subscription_id)
      sync_user_from_subscription(user, subscription) if user
    end

    def user_for_subscription(subscription, subscription_id: stripe_id(subscription.id))
      user_id = subscription.metadata&.user_id
      User.find_by(id: user_id) ||
        User.find_by(stripe_subscription_id: subscription_id) ||
        User.find_by(stripe_customer_id: stripe_id(subscription.customer))
    end

    def sync_user_from_subscription(user, subscription, fallback_tier: nil, fallback_currency: nil)
      item = subscription.items&.data&.first
      price = item&.price
      period_end = subscription.current_period_end.present? ? Time.zone.at(subscription.current_period_end) : nil
      tier = subscription.metadata&.tier.presence || fallback_tier.presence || tier_for_price(price&.id) || user.account_tier
      currency = price&.currency.presence || subscription.metadata&.currency.presence || fallback_currency

      if %w[canceled unpaid incomplete_expired].include?(subscription.status) && (period_end.nil? || period_end.past?)
        tier = "free"
      end

      user.sync_subscription!(
        tier: tier,
        status: subscription.status,
        current_period_end: period_end,
        subscription_id: stripe_id(subscription.id),
        price_id: price&.id,
        currency: currency
      )
    end

    def tier_for_price(price_id)
      return if price_id.blank?

      %w[usd pln].each do |currency|
        %w[premium pro].each do |tier|
          return tier if StripeBilling::Configuration.price_id_for(tier: tier, currency: currency) == price_id
        rescue ArgumentError
          next
        end
      end
      nil
    end

    def stripe_id(value)
      value.respond_to?(:id) ? value.id : value
    end
end
