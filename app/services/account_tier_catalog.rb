class AccountTierCatalog
  def initialize(prices:, interval: "month")
    @prices = prices
    @interval = interval
  end

  def tiers
    [
      {
        name: I18n.t("billing.free_name"),
        key: "free",
        price: prices[:free],
        interval: I18n.t("billing.interval_forever", default: "forever"),
        description: I18n.t("billing.free_desc"),
        features: free_features
      },
      {
        name: I18n.t("billing.premium_name"),
        key: "premium",
        price: prices[:premium],
        interval: interval_label,
        description: I18n.t("billing.premium_desc"),
        features: premium_features
      },
      {
        name: I18n.t("billing.pro_name"),
        key: "pro",
        price: prices[:pro],
        interval: interval_label,
        description: I18n.t("billing.pro_desc"),
        features: pro_features
      }
    ]
  end

  private

  attr_reader :prices, :interval

  def free_features
    [
      feature(:x01),
      feature(:bot_limited),
      feature(:tournaments),
      feature(:remote_matches),
      feature(:match_statistics),
      feature(:training_progress),
      feature(:result_sharing)
    ].tap do |features|
      features << feature(:social_play) if FeatureAccess.enabled?(:friends)
      features << feature(:push_notifications) if FeatureAccess.enabled?(:web_push)
    end
  end

  def premium_features
    [
      feature(:everything_free),
      feature(:bot_unlimited),
      feature(:structured_training),
      feature(:practice_plans),
      feature(:dart_setup),
      feature(:dart_setup_stats),
      feature(:match_review)
    ].tap do |features|
      features << feature(:expanded_training) if FeatureAccess.enabled?(:expanded_training)
      features << feature(:advanced_stats) if FeatureAccess.enabled?(:advanced_stats)
    end
  end

  def pro_features
    [
      feature(:everything_premium),
      feature(:training_recommendations),
      feature(:pro_match_analysis)
    ]
  end

  def feature(key)
    I18n.t("billing.features.#{key}")
  end

  def interval_label
    interval == "year" ? I18n.t("billing.interval_year") : I18n.t("billing.interval_month")
  end
end
