class UserBlock < ApplicationRecord
  include HasPublicId
  public_id_prefix "bl_"

  belongs_to :blocker, class_name: "User"
  belongs_to :blocked, class_name: "User"

  validates :blocker_id, comparison: { other_than: :blocked_id }, uniqueness: { scope: :blocked_id }
end
