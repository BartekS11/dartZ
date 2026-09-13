module Training
  module Modes
    class DoublesPractice < Base
      def mode = "doubles_practice"
      def defaults = { "from" => 1, "to" => 20, "order" => "ascending", "darts_per_target" => 3 }
      def rules = { reporting: "hits / darts", allowed_orders: %w[ascending descending random] }

      def validate!
        from = integer!("from", 1..20)
        to = integer!("to", 1..20)
        integer!("darts_per_target", 1..9)
        raise Training::InvalidAttempt, "from must not exceed to" if from > to
        raise Training::InvalidAttempt, "order is invalid" unless %w[ascending descending random].include?(configuration["order"])
      end

      def targets
        values = (configuration["from"]..configuration["to"]).map { |number| "D#{number}" }
        values.reverse! if configuration["order"] == "descending"
        seed = Digest::SHA256.hexdigest(configuration.to_json).first(8).to_i(16)
        values.shuffle(random: Random.new(seed)) if configuration["order"] == "random"
        values
      end

      def apply(session, result)
        darts = configuration.fetch("darts_per_target")
        hits = result_integer!(result, "hits", 0..darts)
        state = session.state.merge("position" => session.state.fetch("position", 0) + 1)
        { state: state, darts: darts, hits: hits, successful: hits.positive?, complete: complete?(session, state) }
      end
    end
  end
end
