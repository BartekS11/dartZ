class PracticePlan < ApplicationRecord
  include HasPublicId
  public_id_prefix "pp_"

  PLAN_TYPES = %w[beginner_consistency doubles_improvement checkout_improvement scoring_power balanced custom generated].freeze
  STATUSES = %w[active completed archived].freeze

  belongs_to :user
  has_many :practice_plan_tasks, -> { order(:position) }, dependent: :destroy
  alias_method :tasks, :practice_plan_tasks

  validates :title, :plan_type, :status, :started_at, presence: true
  validates :plan_type, inclusion: { in: PLAN_TYPES }
  validates :status, inclusion: { in: STATUSES }

  before_validation :set_started_at, on: :create

  scope :active, -> { where(status: "active") }
  scope :recent_first, -> { order(created_at: :desc) }

  def progress_percent
    return 0 if tasks.empty?

    total_target = tasks.sum(:target_count)
    return 0 if total_target.zero?

    ((tasks.sum(:progress_count).to_f / total_target) * 100).clamp(0, 100).round
  end

  def refresh_completion!
    return unless active?
    return if tasks.empty?
    return unless tasks.all?(&:completed?)

    update!(status: "completed", completed_at: Time.current)
  end

  def completed?
    status == "completed"
  end

  def active?
    status == "active"
  end

  private

  def set_started_at
    self.started_at ||= Time.current
  end
end
