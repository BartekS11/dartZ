class TrainingSessionPracticePlanProgressor
  SEMANTIC_MODES = {
    "doubles_practice" => %w[doubles_practice around_the_clock_doubles],
    "checkout_121" => %w[checkout_121 checkout_randomizer],
    "scoring_99" => %w[scoring_99 around_the_clock]
  }.freeze

  def self.call(training_session)
    new(training_session).call
  end

  def initialize(training_session)
    @training_session = training_session
    @user = training_session.user
  end

  def call
    return unless @training_session.completed?

    @user.practice_plans.active.includes(:practice_plan_tasks).find_each do |plan|
      applicable_modes = SEMANTIC_MODES.fetch(@training_session.mode, [ @training_session.mode ])
      task = plan.tasks.find do |candidate|
        applicable_modes.include?(candidate.training_mode) && !candidate.completed?
      end
      task&.record_progress!(source: "training_session", training_session: @training_session)
    end
  end
end
