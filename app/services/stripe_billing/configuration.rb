module StripeBilling
  class Configuration
    TIERS = %w[premium pro].freeze
    CURRENCIES = %w[usd pln].freeze

    class << self
      def secret_key
        Rails.application.credentials.dig(:stripe, :secret_key).presence || ENV["STRIPE_SECRET_KEY"].presence
      end

      def webhook_secret
        Rails.application.credentials.dig(:stripe, :webhook_secret).presence || ENV["STRIPE_WEBHOOK_SECRET"].presence
      end

      def price_id_for(tier:, currency:)
        tier = tier.to_s
        currency = currency.to_s.downcase
        raise ArgumentError, "Unsupported tier" unless TIERS.include?(tier)
        raise ArgumentError, "Unsupported currency" unless CURRENCIES.include?(currency)

        credential_price_id(tier, currency).presence || ENV["STRIPE_#{tier.upcase}_#{currency.upcase}_PRICE_ID"].presence
      end

      private

      def credential_price_id(tier, currency)
        Rails.application.credentials.dig(:stripe, :prices, tier.to_sym, currency.to_sym)
      end
    end
  end
end
