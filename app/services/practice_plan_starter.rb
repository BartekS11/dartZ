class PracticePlanStarter
  def self.from_template(user:, template_key:)
    template = PracticePlanTemplates.find(template_key) or raise ActiveRecord::RecordInvalid.new(PracticePlan.new)
    create_plan!(user: user, template: template, plan_type: template.key)
  end

  def self.custom(user:, title:, tasks:)
    template = PracticePlanTemplates::Template.new(
      key: "custom",
      title: title.presence || I18n.t("practice_plans.custom_plan"),
      description: I18n.t("practice_plans.custom_description"),
      tasks: tasks
    )
    create_plan!(user: user, template: template, plan_type: "custom")
  end

  def self.generated(user:, stats:)
    key = if stats.fetch(:checkout_rate, 0).to_f < 35
      "checkout_improvement"
    elsif stats.fetch(:double_hit_share, 0).to_f < 20
      "doubles_improvement"
    elsif stats.fetch(:three_dart_average, 0).to_f < 45
      "scoring_power"
    else
      "balanced"
    end

    template = PracticePlanTemplates.find(key)
    create_plan!(user: user, template: template, plan_type: "generated", metadata: { "recommended_from" => key })
  end

  def self.create_plan!(user:, template:, plan_type:, metadata: {})
    PracticePlan.transaction do
      plan = user.practice_plans.create!(
        title: template.title,
        description: template.description,
        plan_type: plan_type,
        recommendation_metadata: metadata
      )

      template.tasks.each_with_index do |task, index|
        plan.tasks.create!(
          title: task.fetch(:title),
          description: task[:description],
          training_mode: task.fetch(:training_mode),
          target_count: task.fetch(:target_count).to_i,
          manual_completion_allowed: true,
          position: index + 1
        )
      end

      plan
    end
  end
end
