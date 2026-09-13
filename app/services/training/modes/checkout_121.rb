module Training
  module Modes
    class Checkout121 < Base
      def mode = "checkout_121"
      def defaults = { "starting_score" => 121, "success_step" => 1, "failures_before_regression" => 3, "regression_step" => 1, "rounds" => 10 }
      def initial_state = { "position" => 0, "checkout" => configuration.fetch("starting_score"), "consecutive_failures" => 0 }
      def targets = Array.new(configuration.fetch("rounds")) { "checkout" }
      def manually_completable? = true
      def rules = configuration.slice("success_step", "failures_before_regression", "regression_step", "rounds")

      def validate!
        integer!("starting_score", 2..170)
        integer!("success_step", 1..20)
        integer!("failures_before_regression", 1..10)
        integer!("regression_step", 1..20)
        integer!("rounds", 1..100)
      end

      def current_target(session)
        score = session.state.fetch("checkout", configuration.fetch("starting_score"))
        { "key" => score.to_s, "label" => score.to_s, "kind" => "checkout", "suggestion" => Array(CheckoutCalculator.suggest(score)).join(" · ") }
      end

      def apply(session, result)
        success = ActiveModel::Type::Boolean.new.cast(result.fetch("checkout", false))
        darts = result_integer!(result, "darts", 1..3)
        state = session.state.deep_dup
        failures = success ? 0 : state.fetch("consecutive_failures", 0) + 1
        checkout = state.fetch("checkout", configuration.fetch("starting_score"))
        if success
          checkout = [ checkout + configuration.fetch("success_step"), 170 ].min
        elsif failures >= configuration.fetch("failures_before_regression")
          checkout = [ checkout - configuration.fetch("regression_step"), 2 ].max
          failures = 0
        end
        position = state.fetch("position", 0) + 1
        state.merge!("position" => position, "checkout" => checkout, "consecutive_failures" => failures)
        { state: state, darts: darts, hits: success ? 1 : 0, successful: success, complete: position >= configuration.fetch("rounds") }
      end
    end
  end
end
