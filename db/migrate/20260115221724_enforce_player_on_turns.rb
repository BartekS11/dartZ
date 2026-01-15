class EnforcePlayerOnTurns < ActiveRecord::Migration[8.1]
  def change
    change_column_null :turns, :player_id, false
  end
end
