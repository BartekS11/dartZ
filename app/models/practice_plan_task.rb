class PracticePlanTask < ApplicationRecord
  belongs_to :practice_plan
  has_many :practice_plan_task_events, dependent: :destroy

  validates :title, :training_mode, presence: true
  validates :training_mode, inclusion: { in: TrainingSession::MODES }
  validates :target_count, numericality: { only_integer: true, greater_than: 0 }
  validates :progress_count, numericality: { only_integer: true, greater_than_or_equal_to: 0 }
  validates :position, numericality: { only_integer: true, greater_than: 0 }

  def completed?
    completed_at.present? || progress_count >= target_count
  end

  def record_progress!(source:, training_session: nil, count: 1)
    count = count.to_i.clamp(1, target_count)
    return if training_session && practice_plan_task_events.exists?(training_session: training_session)
    return if progress_count >= target_count

    transaction do
      practice_plan_task_events.create!(source: source, training_session: training_session, count: count)
      new_count = [ progress_count + count, target_count ].min
      update!(progress_count: new_count, completed_at: (Time.current if new_count >= target_count))
      practice_plan.refresh_completion!
    end
  end

  def manual_complete!
    return false unless manual_completion_allowed?

    record_progress!(source: "manual", count: target_count - progress_count)
  end
end
