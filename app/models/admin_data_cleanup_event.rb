class AdminDataCleanupEvent < ApplicationRecord
  ACTIONS = %w[clear restore purge].freeze

  belongs_to :admin_data_cleanup
  belongs_to :admin_user
  belongs_to :user

  validates :action, inclusion: { in: ACTIONS }
  validates :reason, presence: true, length: { maximum: 2000 }
  validate :batch_belongs_to_user

  before_update { throw :abort }
  before_destroy { throw :abort }

  private

  def batch_belongs_to_user
    return if admin_data_cleanup.nil? || user.nil? || admin_data_cleanup.user_id == user_id

    errors.add(:user, "must match the cleanup batch")
  end
end
