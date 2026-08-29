class TrainingSession < ApplicationRecord
  MODES = %w[around_the_clock around_the_clock_doubles checkout_randomizer].freeze
  STATUSES = %w[active completed abandoned].freeze
  ABANDON_AFTER = 15.days

  include HasPublicId
  public_id_prefix "tr_"

  include TrainingSessionTargets
  include TrainingSessionLifecycle
  include TrainingSessionRecording

  belongs_to :user

  validates :mode, presence: true, inclusion: { in: MODES }
  validates :status, presence: true, inclusion: { in: STATUSES }
  validates :current_target_index, numericality: { greater_than_or_equal_to: 0 }
  validates :total_darts, :misses, :hits, numericality: { greater_than_or_equal_to: 0 }
end
