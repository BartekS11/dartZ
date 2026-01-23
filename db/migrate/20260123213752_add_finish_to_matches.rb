class AddFinishToMatches < ActiveRecord::Migration[8.1]
  def change
    add_column :matches, :finished_at, :datetime
    add_column :matches, :winner_id, :integer
  end
end
