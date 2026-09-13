module Training
  class ModeRegistry
    MODES = {
      "bobs_27" => Training::Modes::Bobs27,
      "doubles_practice" => Training::Modes::DoublesPractice,
      "scoring_99" => Training::Modes::Scoring99,
      "checkout_121" => Training::Modes::Checkout121,
      "custom_targets" => Training::Modes::CustomTargets
    }.freeze

    def self.fetch(mode, configuration = {})
      MODES.fetch(mode.to_s).new(configuration)
    rescue KeyError
      raise Training::InvalidAttempt, "mode is invalid"
    end

    def self.definitions
      MODES.map { |mode, klass| klass.new.definition.merge(name_key: "training.modes.#{mode}.name") }
    end
  end
end
