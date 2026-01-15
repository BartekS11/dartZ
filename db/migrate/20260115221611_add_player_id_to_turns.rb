class AddPlayerIdToTurns < ActiveRecord::Migration[8.1]
  def change
    add_column :turns, :player_id, :bigint
    add_index :turns, :player_id
    add_foreign_key :turns, :players
  end
end
