class AddResponseToTrainingAttempts < ActiveRecord::Migration[8.1]
  def change
    add_column :training_attempts, :response, :jsonb, null: false, default: {}
  end
end
