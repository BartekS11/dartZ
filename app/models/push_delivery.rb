class PushDelivery < ApplicationRecord
  CATEGORIES = (NotificationPreference::CATEGORIES + [ "test" ]).freeze
  STATUSES = %w[pending delivered failed cancelled].freeze

  belongs_to :push_subscription

  validates :category, inclusion: { in: CATEGORIES }
  validates :deduplication_key, presence: true, length: { maximum: 200 }, uniqueness: { scope: :push_subscription_id }
  validates :status, inclusion: { in: STATUSES }
  validates :attempts, numericality: { only_integer: true, greater_than_or_equal_to: 0 }
  validate :safe_payload

  scope :pending, -> { where(status: "pending") }

  private

  def safe_payload
    data = payload.to_h
    errors.add(:payload, :invalid) unless data.keys.sort == %w[body path title]
    errors.add(:payload, :invalid) unless data.values.all? { |value| value.is_a?(String) }
    path = data["path"].to_s
    errors.add(:payload, :invalid) unless path.start_with?("/") && !path.start_with?("//") && !path.include?("\\")
  end
end
