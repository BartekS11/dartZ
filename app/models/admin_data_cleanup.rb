class AdminDataCleanup < ApplicationRecord
  include HasPublicId
  public_id_prefix "adc_"

  CATEGORIES = %w[matches training_sessions practice_plans training_drills tournaments dart_setup].freeze
  STATUSES = %w[cleared restored purged].freeze

  belongs_to :user
  has_many :events, -> { order(:created_at, :id) }, class_name: "AdminDataCleanupEvent", dependent: :restrict_with_error

  validates :categories, presence: true
  validates :status, inclusion: { in: STATUSES }
  validate :valid_categories

  def cleared?
    status == "cleared"
  end

  private

  def valid_categories
    values = Array(categories)
    errors.add(:categories, "contain an unsupported value") unless values.any? && (values - CATEGORIES).empty?
  end
end
