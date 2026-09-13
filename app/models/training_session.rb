class TrainingSession < ApplicationRecord
  LEGACY_MODES = %w[around_the_clock around_the_clock_doubles checkout_randomizer].freeze
  EXPANDED_MODES = %w[bobs_27 doubles_practice scoring_99 checkout_121 custom_targets].freeze
  MODES = (LEGACY_MODES + EXPANDED_MODES).freeze
  STATUSES = %w[active completed abandoned].freeze
  ABANDON_AFTER = 15.days

  include HasPublicId
  public_id_prefix "tr_"

  include TrainingSessionTargets
  include TrainingSessionLifecycle
  include TrainingSessionRecording

  belongs_to :user
  belongs_to :admin_data_cleanup, optional: true
  has_many :training_attempts, -> { order(:sequence) }, dependent: :destroy
  has_many :practice_plan_task_events, dependent: :nullify

  scope :kept, -> { where(admin_data_cleanup_id: nil) }
  scope :admin_cleared, -> { where.not(admin_data_cleanup_id: nil) }

  before_validation :initialize_expanded_mode, on: :create

  validates :mode, presence: true, inclusion: { in: MODES }
  validates :status, presence: true, inclusion: { in: STATUSES }
  validates :current_target_index, numericality: { greater_than_or_equal_to: 0 }
  validates :total_darts, :misses, :hits, numericality: { greater_than_or_equal_to: 0 }
  validate :validate_expanded_configuration

  def expanded_mode?
    EXPANDED_MODES.include?(mode)
  end

  def mode_definition
    Training::ModeRegistry.fetch(mode, configuration)
  end

  def session_progress
    expanded_mode? ? mode_definition.progress(self) : { current: current_target_index, total: targets.length, percent: progress_percent }
  end

  def summary
    base = { darts: total_darts, hits: hits, misses: misses, hit_rate: total_darts.zero? ? nil : (hits.to_f / total_darts * 100).round(1) }
    base[:score] = score if score
    base.merge!(mode_definition.progress(self)) if expanded_mode?
    base
  end

  private

  def initialize_expanded_mode
    return unless expanded_mode?

    definition = mode_definition
    self.configuration = definition.configuration
    self.state = definition.initial_state if state.blank?
    self.score = definition.initial_score if score.nil?
  rescue Training::InvalidAttempt
    # Validation below exposes the configuration error on the model.
  end

  def validate_expanded_configuration
    mode_definition if expanded_mode?
  rescue Training::InvalidAttempt => error
    errors.add(:configuration, error.message)
  end
end
