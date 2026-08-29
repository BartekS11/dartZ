class AddStartingPlayerPositionToMatches < ActiveRecord::Migration[8.1]
  def change
    add_column :matches, :starting_player_position, :integer, null: false, default: 1
  end
end
