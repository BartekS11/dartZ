class StripeWebhooksController < ActionController::API
  def create
    return head :bad_request if StripeBilling::Configuration.webhook_secret.blank?

    StripeBilling::Event.new(build_event).process
    head :ok
  rescue JSON::ParserError, Stripe::SignatureVerificationError
    head :bad_request
  rescue ActiveRecord::RecordNotFound => e
    Rails.logger.warn("Stripe webhook user not found: #{e.message}")
    head :ok
  rescue Stripe::StripeError => e
    Rails.logger.error("Stripe webhook API error: #{e.class}: #{e.message}")
    head :bad_gateway
  end

  private
    def build_event
      Stripe::Webhook.construct_event(
        request.raw_post,
        request.env["HTTP_STRIPE_SIGNATURE"],
        StripeBilling::Configuration.webhook_secret
      )
    end
end
