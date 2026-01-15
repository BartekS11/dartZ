class Player < ApplicationRecord
  belongs_to :user, optional: true
  belongs_to :match

  validates :name, presence: true

  def guest?
    user_id.nil?
  end

  def display_name
    guest? ? name : user.email_address
  end
end

