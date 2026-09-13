module Training
  module Modes
    class Base
      attr_reader :configuration

      def initialize(configuration = {})
        @configuration = defaults.merge((configuration || {}).stringify_keys)
        validate!
      end

      def defaults = {}
      def initial_state = { "position" => 0 }
      def initial_score = nil
      def manually_completable? = false
      def validate! = true

      def definition
        { mode: mode, configuration: configuration, rules: rules }
      end

      def progress(session)
        { current: session.state.fetch("position", 0), total: targets.length, percent: percent(session) }
      end

      def current_target(session)
        target = targets[session.state.fetch("position", 0)]
        target && { "key" => target, "label" => target, "kind" => target_kind }
      end

      def complete?(session, state)
        state.fetch("position", 0) >= targets.length
      end

      private

      def integer!(key, range)
        value = Integer(configuration.fetch(key))
        raise Training::InvalidAttempt, "#{key} is outside the allowed range" unless range.cover?(value)

        configuration[key] = value
      rescue ArgumentError, TypeError, KeyError
        raise Training::InvalidAttempt, "#{key} must be an integer"
      end

      def result_integer!(result, key, range)
        value = Integer(result.fetch(key))
        raise Training::InvalidAttempt, "#{key} is outside the allowed range" unless range.cover?(value)

        value
      rescue ArgumentError, TypeError, KeyError
        raise Training::InvalidAttempt, "#{key} must be an integer"
      end

      def percent(session)
        total = targets.length
        total.zero? ? 0 : ((session.state.fetch("position", 0).to_f / total) * 100).round
      end

      def target_kind = "target"
    end
  end
end
