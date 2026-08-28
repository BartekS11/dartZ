class TrainingStats
  RECENT_WINDOW = 5

  def initialize(user:)
    @user = user
  end

  def summary
    TrainingSession::MODES.map { |mode| mode_summary(mode) }
  end

  private

  attr_reader :user

  def completed_sessions(mode)
    user.training_sessions.where(mode: mode, status: "completed").order(completed_at: :desc, created_at: :desc)
  end

  def mode_summary(mode)
    sessions = completed_sessions(mode).to_a
    recent = sessions.first(RECENT_WINDOW)
    previous = sessions.drop(RECENT_WINDOW).first(RECENT_WINDOW)
    recent_average = average_darts(recent)
    previous_average = average_darts(previous)
    delta = recent_average && previous_average ? (recent_average - previous_average).round(1) : nil

    {
      mode: mode,
      completed_count: sessions.size,
      best_darts: sessions.map(&:total_darts).compact.min,
      recent_average: recent_average,
      previous_average: previous_average,
      delta: delta,
      trend: trend(delta)
    }
  end

  def average_darts(sessions)
    return nil if sessions.blank?

    (sessions.sum(&:total_darts).to_f / sessions.size).round(1)
  end

  def trend(delta)
    return "neutral" if delta.blank? || delta.zero?

    delta.negative? ? "improved" : "declined"
  end
end
