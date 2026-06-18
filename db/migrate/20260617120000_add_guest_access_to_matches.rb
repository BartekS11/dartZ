class AddGuestAccessToMatches < ActiveRecord::Migration[8.1]
  def change
    add_column :matches, :guest_token, :string
    add_column :matches, :guest_id, :string

    add_index :matches, :guest_token, unique: true
    add_index :matches, :guest_id
  end
end
