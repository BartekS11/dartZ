class PracticePlanTaskEvent < ApplicationRecord
  SOURCES = %w[training_session manual].freeze

  belongs_to :practice_plan_task
  belongs_to :training_session, optional: true

  validates :source, presence: true, inclusion: { in: SOURCES }
  validates :count, numericality: { only_integer: true, greater_than: 0 }
end
