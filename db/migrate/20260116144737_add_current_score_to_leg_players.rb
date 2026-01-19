class AddCurrentScoreToLegPlayers < ActiveRecord::Migration[8.1]
  def change
    add_column :leg_players, :current_score, :integer
  end
end
