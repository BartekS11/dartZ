class AddScoreToLegPlayers < ActiveRecord::Migration[8.1]
  def change
    add_column :leg_players, :score, :integer
  end
end
