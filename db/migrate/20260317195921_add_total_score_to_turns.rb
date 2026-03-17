class AddTotalScoreToTurns < ActiveRecord::Migration[8.1]
  def change
    add_column :turns, :total_score, :integer
  end
end
