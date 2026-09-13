class FeatureAccess
  Definition = Data.define(:environment_key, :premium)

  DEFINITIONS = {
    advanced_stats: Definition.new(environment_key: "ADVANCED_STATS_ENABLED", premium: true),
    expanded_training: Definition.new(environment_key: "EXPANDED_TRAINING_ENABLED", premium: true),
    friends: Definition.new(environment_key: "FRIENDS_ENABLED", premium: false),
    web_push: Definition.new(environment_key: "WEB_PUSH_ENABLED", premium: false),
    offline_scoring: Definition.new(environment_key: "OFFLINE_SCORING_ENABLED", premium: true)
  }.freeze

  class << self
    def enabled?(feature)
      Rails.configuration.x.roadmap_features.fetch(normalize(feature))
    end

    def entitled?(feature, user:)
      definition = definition_for(feature)
      return false unless user

      !definition.premium || user.premium_access?
    end

    def available?(feature, user:)
      enabled?(feature) && entitled?(feature, user: user)
    end

    def definition_for(feature)
      DEFINITIONS.fetch(normalize(feature))
    end

    private

    def normalize(feature)
      feature.to_sym
    end
  end
end
