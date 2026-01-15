class Player < ApplicationRecord
  belongs_to :user
  belongs_to :match

  validates :user, :match, presence: true
end
