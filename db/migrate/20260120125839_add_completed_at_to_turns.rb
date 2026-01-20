class AddCompletedAtToTurns < ActiveRecord::Migration[8.1]
  def change
    add_column :turns, :completed_at, :datetime
  end
end
