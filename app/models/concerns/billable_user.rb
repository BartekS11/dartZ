module BillableUser
  extend ActiveSupport::Concern

  def premium_access?
    return false if account_tier == "free"
    return true if premium_access_expires_at.blank?

    premium_access_expires_at.future?
  end

  def subscribed?
    stripe_subscription_id.present? && %w[active trialing past_due].include?(stripe_subscription_status)
  end

  def subscription_expired?
    return false if account_tier == "free"
    return false if premium_access_expires_at.blank?

    premium_access_expires_at.past?
  end

  def sync_subscription!(tier:, status:, current_period_end:, subscription_id: nil, price_id: nil, currency: nil)
    update!(
      account_tier: tier.presence || account_tier,
      stripe_subscription_id: subscription_id.presence || stripe_subscription_id,
      stripe_subscription_status: status,
      stripe_price_id: price_id.presence || stripe_price_id,
      subscription_currency: currency.presence || subscription_currency,
      premium_access_expires_at: current_period_end
    )
  end
end
