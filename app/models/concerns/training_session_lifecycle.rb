module TrainingSessionLifecycle
  extend ActiveSupport::Concern

  included do
    before_validation :set_started_at, on: :create
    before_validation :set_initial_checkout_score, on: :create

    scope :recent_first, -> { order(created_at: :desc) }
    scope :active, -> { where(status: "active") }
  end

  class_methods do
    def abandon_stale!
      active.where(started_at: ...TrainingSession::ABANDON_AFTER.ago).find_each(&:abandon!)
    end
  end

  def completed?
    status == "completed"
  end

  def active?
    status == "active"
  end

  def abandoned?
    status == "abandoned"
  end

  def doubles_mode?
    mode == "around_the_clock_doubles"
  end

  def checkout_randomizer_mode?
    mode == "checkout_randomizer"
  end

  def progress_percent
    return 0 if checkout_randomizer_mode? || targets.empty?

    ((current_target_index.to_f / targets.length) * 100).round
  end

  def duration_seconds
    finish_time = completed_at || abandoned_at || Time.current
    return 0 if started_at.blank?

    [ (finish_time - started_at).to_i, 0 ].max
  end

  def complete!
    return false unless active?

    update!(status: "completed", completed_at: Time.current).tap do |completed|
      TrainingSessionPracticePlanProgressor.call(self) if completed
    end
  end

  def abandon!
    return false unless active?

    update!(status: "abandoned", abandoned_at: Time.current)
  end

  private

  def set_started_at
    self.started_at ||= Time.current
  end

  def set_initial_checkout_score
    self.current_target_index = random_checkout_score if checkout_randomizer_mode? && current_target_index.zero?
  end
end
