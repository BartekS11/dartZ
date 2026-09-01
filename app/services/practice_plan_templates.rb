class PracticePlanTemplates
  Template = Struct.new(:key, :title, :description, :tasks, keyword_init: true)

  def self.all
    [
      Template.new(
        key: "beginner_consistency",
        title: I18n.t("practice_plans.templates.beginner_consistency.title"),
        description: I18n.t("practice_plans.templates.beginner_consistency.description"),
        tasks: [
          task("around_the_clock", 2, "Around the Clock x2"),
          task("checkout_randomizer", 1, "Checkout confidence")
        ]
      ),
      Template.new(
        key: "doubles_improvement",
        title: I18n.t("practice_plans.templates.doubles_improvement.title"),
        description: I18n.t("practice_plans.templates.doubles_improvement.description"),
        tasks: [ task("around_the_clock_doubles", 3, "Doubles routine x3") ]
      ),
      Template.new(
        key: "checkout_improvement",
        title: I18n.t("practice_plans.templates.checkout_improvement.title"),
        description: I18n.t("practice_plans.templates.checkout_improvement.description"),
        tasks: [ task("checkout_randomizer", 4, "Checkout randomizer x4") ]
      ),
      Template.new(
        key: "scoring_power",
        title: I18n.t("practice_plans.templates.scoring_power.title"),
        description: I18n.t("practice_plans.templates.scoring_power.description"),
        tasks: [ task("around_the_clock", 3, "Scoring consistency x3") ]
      ),
      Template.new(
        key: "balanced",
        title: I18n.t("practice_plans.templates.balanced.title"),
        description: I18n.t("practice_plans.templates.balanced.description"),
        tasks: [
          task("around_the_clock", 2, "Numbers x2"),
          task("around_the_clock_doubles", 2, "Doubles x2"),
          task("checkout_randomizer", 2, "Checkouts x2")
        ]
      )
    ]
  end

  def self.find(key)
    all.find { |template| template.key == key.to_s }
  end

  def self.task(training_mode, target_count, title)
    { training_mode: training_mode, target_count: target_count, title: title, description: I18n.t("training.modes.#{training_mode}.name") }
  end
end
