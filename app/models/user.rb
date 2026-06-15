class User < ApplicationRecord
  has_secure_password
  has_many :sessions, dependent: :destroy
  has_many :players, dependent: :destroy

  normalizes :email_address, with: ->(e) { e.strip.downcase }
  normalizes :nickname, with: ->(n) { n.to_s.strip.presence }

  validates :nickname, length: { maximum: 20 }, allow_blank: true

  def display_name
    nickname.presence || email_address
  end
end
