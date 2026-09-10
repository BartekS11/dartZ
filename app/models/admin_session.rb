class AdminSession < ApplicationRecord
  LIFETIME = 12.hours

  belongs_to :admin_user

  validates :expires_at, presence: true

  scope :active, -> { where(expires_at: Time.current..) }

  def expired?
    expires_at <= Time.current
  end
end
