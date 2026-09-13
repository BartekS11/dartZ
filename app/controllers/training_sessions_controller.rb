class TrainingSessionsController < ApplicationController
  before_action :require_training_access
  before_action :set_training_session, only: %i[show record complete abandon]

  def index
    TrainingSession.abandon_stale!
    @active_sessions = Current.user.training_sessions.active.recent_first
    @training_history_mode = params[:training_mode].presence_in(TrainingSession::MODES) || "all"
    @training_history_limit = params[:limit].to_i.presence_in([ 5, 10, 25, 50 ]) || 25
    @training_sessions = filtered_training_history.limit(@training_history_limit)
    @available_modes = TrainingSession::LEGACY_MODES + (FeatureAccess.enabled?(:expanded_training) ? TrainingSession::EXPANDED_MODES : [])
    @training_stats = TrainingStats.new(user: Current.user).summary.select { |stat| @available_modes.include?(stat[:mode]) }
  end

  def create
    mode = training_session_params[:mode]
    return head :not_found if TrainingSession::EXPANDED_MODES.include?(mode) && !FeatureAccess.enabled?(:expanded_training)

    @training_session = if TrainingSession::EXPANDED_MODES.include?(mode)
      Training::SessionStarter.call(user: Current.user, mode: mode, configuration: expanded_configuration)
    else
      Current.user.training_sessions.create!(mode: mode)
    end
    redirect_to training_session_path(@training_session), notice: t("training.flashes.started")
  rescue ActiveRecord::RecordInvalid, Training::InvalidAttempt
    redirect_to training_sessions_path, alert: t("training.flashes.invalid_mode")
  end

  def show
    @training_session.abandon! if @training_session.active? && @training_session.started_at < TrainingSession::ABANDON_AFTER.ago
  end

  def record
    if @training_session.expanded_mode?
      return head :not_found unless FeatureAccess.enabled?(:expanded_training)

      Training::AttemptRecorder.call(
        session: @training_session,
        idempotency_key: params[:idempotency_key].presence || SecureRandom.uuid,
        result: expanded_result
      )
    elsif params[:result] == "hit"
      @training_session.record_hit!(misses_before_hit: params[:misses])
    else
      @training_session.record_no_hit!(misses_count: params[:misses])
    end

    redirect_to training_session_path(@training_session)
  rescue Training::InvalidAttempt => error
    redirect_to training_session_path(@training_session), alert: error.message
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
    head :not_found if @training_session.expanded_mode? && !FeatureAccess.enabled?(:expanded_training)
  end

  def training_session_params
    params.require(:training_session).permit(:mode, :from, :to, :order, :darts_per_target, :starting_score,
      :success_step, :failures_before_regression, :regression_step, :rounds, :name, :targets, :repetitions, :required_hits)
  end

  def expanded_configuration
    values = training_session_params.except(:mode).to_h.compact_blank
    values["targets"] = values["targets"].split(",").map(&:strip) if values["targets"].present?
    values
  end

  def expanded_result
    case @training_session.mode
    when "scoring_99"
      { score: params[:score], darts: params[:darts] }
    when "checkout_121"
      { checkout: params[:result] == "hit", darts: params[:darts].presence || 3 }
    else
      { hits: params[:hits].presence || (params[:result] == "hit" ? 1 : 0) }
    end
  end

  def filtered_training_history
    scope = Current.user.training_sessions.where.not(status: "active").recent_first
    return scope if @training_history_mode == "all"

    scope.where(mode: @training_history_mode)
  end
end
