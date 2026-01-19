class AddUniqueIndexToLegPlayers < ActiveRecord::Migration[8.1]
  def change
    add_index :leg_players, [ :leg_id, :player_id ], unique: true
  end
end
