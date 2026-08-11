class BillingController < ApplicationController
  def show
    @tiers = [
      {
        name: I18n.t("billing.free_name"),
        key: "free",
        price: "$0",
        interval: I18n.t("billing.interval_forever", default: "forever"),
        description: I18n.t("billing.free_desc"),
        features: [
          I18n.t("billing.features.x01", default: "X01 scoreboard"),
          I18n.t("billing.features.bot", default: "Bot matches"),
          I18n.t("billing.features.tournament_browsing", default: "Tournament browsing"),
          I18n.t("billing.features.local_history", default: "Local match history")
        ]
      },
      {
        name: I18n.t("billing.premium_name"),
        key: "premium",
        price: "$4.99",
        interval: I18n.t("billing.interval_month"),
        description: I18n.t("billing.premium_desc"),
        features: [
          I18n.t("billing.features.everything_free", default: "Everything in Free"),
          I18n.t("billing.features.dart_setup"),
          I18n.t("billing.features.dart_details", default: "Manufacturer, weight, shaft, and point details"),
          I18n.t("billing.features.premium_stats", default: "Future premium stats and preferences")
        ]
      },
      {
        name: I18n.t("billing.pro_name"),
        key: "pro",
        price: "$9.99",
        interval: I18n.t("billing.interval_month"),
        description: I18n.t("billing.pro_desc"),
        features: [
          I18n.t("billing.features.everything_premium", default: "Everything in Premium"),
          I18n.t("billing.features.advanced_stats"),
          I18n.t("billing.features.league_tools", default: "Future league tools"),
          I18n.t("billing.features.priority")
        ]
      }
    ]
  end
end
