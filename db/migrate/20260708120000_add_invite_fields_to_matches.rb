class AddInviteFieldsToMatches < ActiveRecord::Migration[8.1]
  def change
    add_column :matches, :invite_token, :string
    add_column :matches, :invite_created_at, :datetime
    add_column :matches, :invite_expires_at, :datetime
    add_column :matches, :invite_joined_at, :datetime
    add_column :matches, :invite_cancelled_at, :datetime

    add_index :matches, :invite_token, unique: true
    add_index :matches, :invite_expires_at
  end
end
