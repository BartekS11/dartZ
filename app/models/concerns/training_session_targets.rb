module TrainingSessionTargets
  extend ActiveSupport::Concern

  def targets
    return [] if checkout_randomizer_mode?

    numeric_targets = (1..20).map do |number|
      {
        "key" => number.to_s,
        "label" => doubles_mode? ? "D#{number}" : number.to_s,
        "number" => number,
        "kind" => doubles_mode? ? "double" : "any"
      }
    end

    numeric_targets + [
      { "key" => "outer_bull", "label" => "Outer Bull", "number" => 25, "kind" => "outer_bull" },
      { "key" => "inner_bull", "label" => "Inner Bull", "number" => 50, "kind" => "inner_bull" }
    ]
  end

  def current_target
    return checkout_target if checkout_randomizer_mode?

    targets[current_target_index]
  end

  private

  def checkout_target
    score = current_target_index
    {
      "key" => score.to_s,
      "label" => score.to_s,
      "score" => score,
      "kind" => "checkout",
      "suggestion" => Array(CheckoutCalculator.suggest(score)).join(" · ")
    }
  end

  def random_checkout_score
    CheckoutCalculator::CHECKOUT_TABLE.keys.sample
  end
end
