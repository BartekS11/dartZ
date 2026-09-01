class PracticePlansController < ApplicationController
  before_action :require_premium_access
  before_action :set_plan, only: %i[show complete_task]

  def index
    @templates = PracticePlanTemplates.all
    @active_plans = Current.user.practice_plans.active.recent_first.includes(:practice_plan_tasks)
    @completed_plans = Current.user.practice_plans.where(status: "completed").recent_first.limit(10)
  end

  def show
  end

  def create
    plan = if params[:template_key].present?
      PracticePlanStarter.from_template(user: Current.user, template_key: params[:template_key])
    elsif params[:generated].present?
      stats = MatchStatsDashboard.new(user: Current.user).summary
      PracticePlanStarter.generated(user: Current.user, stats: stats)
    else
      PracticePlanStarter.custom(user: Current.user, title: params[:title], tasks: custom_tasks)
    end

    redirect_to practice_plan_path(plan), notice: t("practice_plans.flashes.started")
  rescue ActiveRecord::RecordInvalid, KeyError
    redirect_to practice_plans_path, alert: t("practice_plans.flashes.invalid")
  end

  def complete_task
    task = @practice_plan.tasks.find(params[:task_id])
    task.manual_complete!
    redirect_to practice_plan_path(@practice_plan), notice: t("practice_plans.flashes.task_completed")
  end

  private

  def set_plan
    @practice_plan = Current.user.practice_plans.find_by!(public_id: params[:id] || params[:practice_plan_id])
  end

  def custom_tasks
    task_params_list = params.fetch(:tasks, {}).to_unsafe_h.values
    modes = task_params_list.filter_map do |task_params|
      mode = task_params[:training_mode] || task_params["training_mode"]
      next unless TrainingSession::MODES.include?(mode)

      {
        title: I18n.t("training.modes.#{mode}.name"),
        description: I18n.t("practice_plans.custom_task_description"),
        training_mode: mode,
        target_count: (task_params[:target_count] || task_params["target_count"]).to_i.clamp(1, 20)
      }
    end
    modes.presence || [ PracticePlanTemplates.task("around_the_clock", 1, I18n.t("training.modes.around_the_clock.name")) ]
  end
end
