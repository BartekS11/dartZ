class TrainingAttempt < ApplicationRecord
  include HasPublicId
  public_id_prefix "ta_"

  belongs_to :training_session

  validates :idempotency_key, presence: true, uniqueness: { scope: :training_session_id },
    format: { with: /\A[0-9a-f]{8}-[0-9a-f]{4}-[1-5][0-9a-f]{3}-[89ab][0-9a-f]{3}-[0-9a-f]{12}\z/i }
  validates :sequence, numericality: { only_integer: true, greater_than: 0 }, uniqueness: { scope: :training_session_id }
  validates :target, presence: true
  validates :darts, numericality: { only_integer: true, in: 1..99 }
  validates :hits, numericality: { only_integer: true, greater_than_or_equal_to: 0 }
  validate :hits_do_not_exceed_darts

  private

  def hits_do_not_exceed_darts
    errors.add(:hits, :less_than_or_equal_to, count: darts) if darts && hits && hits > darts
  end
end
