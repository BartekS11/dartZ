class AddPlayerDisplayReversedToMatches < ActiveRecord::Migration[8.1]
  def change
    add_column :matches, :player_display_reversed, :boolean, default: false, null: false
  end
end
