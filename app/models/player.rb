class Player < ApplicationRecord
  belongs_to :user
has_many :matches, dependent: :destroy
end
