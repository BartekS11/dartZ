class RemoveStartingScoreFromTurns < ActiveRecord::Migration[8.1]
  def change
    remove_column :turns, :starting_score, :integer
  end
end
