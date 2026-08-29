class TrainingSessionsController < ApplicationController
  before_action :require_training_access
  before_action :set_training_session, only: %i[show record complete abandon]

  def index
    TrainingSession.abandon_stale!
    @active_sessions = Current.user.training_sessions.active.recent_first
    @training_history_mode = params[:training_mode].presence_in(TrainingSession::MODES) || "all"
    @training_history_limit = params[:limit].to_i.presence_in([ 5, 10, 25, 50 ]) || 25
    @training_sessions = filtered_training_history.limit(@training_history_limit)
    @training_stats = TrainingStats.new(user: Current.user).summary
  end

  def create
    @training_session = Current.user.training_sessions.create!(mode: training_session_params[:mode])
    redirect_to training_session_path(@training_session), notice: t("training.flashes.started")
  rescue ActiveRecord::RecordInvalid
    redirect_to training_sessions_path, alert: t("training.flashes.invalid_mode")
  end

  def show
    @training_session.abandon! if @training_session.active? && @training_session.started_at < TrainingSession::ABANDON_AFTER.ago
  end

  def record
    if params[:result] == "hit"
      @training_session.record_hit!(misses_before_hit: params[:misses])
    else
      @training_session.record_no_hit!(misses_count: params[:misses])
    end

    redirect_to training_session_path(@training_session)
  end

  def complete
    @training_session.complete!
    redirect_to training_sessions_path, notice: t("training.flashes.completed")
  end

  def abandon
    @training_session.abandon!
    redirect_to training_sessions_path, notice: t("training.flashes.abandoned")
  end

  private

  def require_training_access
    return if premium_access?

    redirect_to billing_path, alert: t("flashes.premium_required")
  end

  def set_training_session
    @training_session = Current.user.training_sessions.find_by!(public_id: params[:id])
  end

  def training_session_params
    params.require(:training_session).permit(:mode)
  end

  def filtered_training_history
    scope = Current.user.training_sessions.where.not(status: "active").recent_first
    return scope if @training_history_mode == "all"

    scope.where(mode: @training_history_mode)
  end
end
