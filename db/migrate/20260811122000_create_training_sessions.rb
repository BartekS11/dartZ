class CreateTrainingSessions < ActiveRecord::Migration[8.1]
  def change
    create_table :training_sessions do |t|
      t.references :user, null: false, foreign_key: true
      t.string :mode, null: false
      t.string :status, null: false, default: "active"
      t.integer :current_target_index, null: false, default: 0
      t.integer :total_darts, null: false, default: 0
      t.integer :misses, null: false, default: 0
      t.integer :hits, null: false, default: 0
      t.jsonb :target_stats, null: false, default: []
      t.datetime :started_at, null: false
      t.datetime :completed_at
      t.datetime :abandoned_at
      t.timestamps
    end

    add_index :training_sessions, [ :user_id, :status ]
    add_index :training_sessions, [ :user_id, :created_at ]
  end
end
