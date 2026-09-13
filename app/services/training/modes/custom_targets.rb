module Training
  module Modes
    class CustomTargets < Base
      TARGET_PATTERN = /\A(?:[SDT](?:[1-9]|1\d|20)|OB|IB)\z/

      def mode = "custom_targets"
      def defaults = { "targets" => [ "S20" ], "darts_per_target" => 3, "repetitions" => 1, "required_hits" => 1 }
      def targets = configuration.fetch("targets") * configuration.fetch("repetitions")
      def rules = configuration.slice("darts_per_target", "repetitions", "required_hits")

      def validate!
        values = Array(configuration["targets"]).map { |target| target.to_s.upcase }
        raise Training::InvalidAttempt, "targets must contain between 1 and 50 valid dartboard targets" unless values.size.in?(1..50) && values.all? { |target| TARGET_PATTERN.match?(target) }

        configuration["targets"] = values
        darts = integer!("darts_per_target", 1..9)
        integer!("repetitions", 1..20)
        required = integer!("required_hits", 1..darts)
        raise Training::InvalidAttempt, "required_hits cannot exceed darts_per_target" if required > darts
      end

      def apply(session, result)
        darts = configuration.fetch("darts_per_target")
        hits = result_integer!(result, "hits", 0..darts)
        position = session.state.fetch("position", 0) + 1
        state = session.state.merge("position" => position)
        { state: state, darts: darts, hits: hits, successful: hits >= configuration.fetch("required_hits"), complete: position >= targets.length }
      end
    end
  end
end
