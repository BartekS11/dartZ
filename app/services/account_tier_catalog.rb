class AccountTierCatalog
  def initialize(prices:)
    @prices = prices
  end

  def tiers
    [
      {
        name: I18n.t("billing.free_name"),
        key: "free",
        price: prices[:free],
        interval: I18n.t("billing.interval_forever", default: "forever"),
        description: I18n.t("billing.free_desc"),
        features: [
          I18n.t("billing.features.x01", default: "X01 scoreboard"),
          I18n.t("billing.features.bot_limited", default: "40 bot matches/week, up to Bo5"),
          I18n.t("billing.features.tournament_browsing", default: "Tournament browsing"),
          I18n.t("billing.features.local_history", default: "Local match history")
        ]
      },
      {
        name: I18n.t("billing.premium_name"),
        key: "premium",
        price: prices[:premium],
        interval: I18n.t("billing.interval_month"),
        description: I18n.t("billing.premium_desc"),
        features: [
          I18n.t("billing.features.everything_free", default: "Everything in Free"),
          I18n.t("billing.features.bot_unlimited", default: "Unlimited bot matches"),
          I18n.t("billing.features.dart_setup"),
          I18n.t("billing.features.dart_details", default: "Manufacturer, weight, shaft, and point details"),
          I18n.t("billing.features.premium_stats", default: "Future premium stats and preferences")
        ]
      },
      {
        name: I18n.t("billing.pro_name"),
        key: "pro",
        price: prices[:pro],
        interval: I18n.t("billing.interval_month"),
        description: I18n.t("billing.pro_desc"),
        features: [
          I18n.t("billing.features.everything_premium", default: "Everything in Premium"),
          I18n.t("billing.features.bot_unlimited", default: "Unlimited bot matches"),
          I18n.t("billing.features.advanced_stats"),
          I18n.t("billing.features.league_tools", default: "Future league tools"),
          I18n.t("billing.features.priority")
        ]
      }
    ]
  end

  private

  attr_reader :prices
end
