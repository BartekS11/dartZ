class BillingController < ApplicationController
  def show
    @tiers = [
      {
        name: "Free",
        key: "free",
        price: "$0",
        interval: "forever",
        description: "Core match scoring for casual play.",
        features: [
          "X01 scoreboard",
          "Bot matches",
          "Tournament browsing",
          "Local match history"
        ]
      },
      {
        name: "Premium",
        key: "premium",
        price: "$4.99",
        interval: "month",
        description: "Personal tools for regular players.",
        features: [
          "Everything in Free",
          "Save your dart setup",
          "Manufacturer, weight, shaft, and point details",
          "Future premium stats and preferences"
        ]
      },
      {
        name: "Pro",
        key: "pro",
        price: "$9.99",
        interval: "month",
        description: "Advanced features for leagues and power users.",
        features: [
          "Everything in Premium",
          "Future advanced analytics",
          "Future league tools",
          "Future priority features"
        ]
      }
    ]
  end
end
