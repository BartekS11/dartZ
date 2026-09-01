class TrainingSessionPracticePlanProgressor
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
      task = plan.tasks.find do |candidate|
        candidate.training_mode == @training_session.mode && !candidate.completed?
      end
      task&.record_progress!(source: "training_session", training_session: @training_session)
    end
  end
end
