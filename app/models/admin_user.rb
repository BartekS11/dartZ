class AdminUser < ApplicationRecord
  has_secure_password

  has_many :admin_sessions, dependent: :destroy
  has_many :admin_tier_changes, dependent: :restrict_with_error

  normalizes :email_address, with: ->(email) { email.to_s.strip.downcase }

  validates :email_address, presence: true, uniqueness: { case_sensitive: false }
  validates :password, length: { minimum: 16 }, if: -> { new_record? || password.present? }
end
