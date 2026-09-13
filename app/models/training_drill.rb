class TrainingDrill < ApplicationRecord
  include HasPublicId
  public_id_prefix "td_"

  belongs_to :user
  belongs_to :admin_data_cleanup, optional: true

  scope :kept, -> { where(admin_data_cleanup_id: nil) }
  scope :admin_cleared, -> { where.not(admin_data_cleanup_id: nil) }

  validates :name, presence: true, length: { maximum: 80 }, uniqueness: { scope: :user_id, conditions: -> { kept } }
  validate :valid_configuration

  private

  def valid_configuration
    Training::Modes::CustomTargets.new(configuration).validate!
  rescue Training::InvalidAttempt => error
    errors.add(:configuration, error.message)
  end
end
