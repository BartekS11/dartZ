class ExpandTrainingSessions < ActiveRecord::Migration[8.1]
  def change
    change_table :training_sessions, bulk: true do |t|
      t.jsonb :configuration, null: false, default: {}
      t.jsonb :state, null: false, default: {}
      t.integer :score
    end

    create_table :training_drills do |t|
      t.references :user, null: false, foreign_key: true
      t.string :public_id, null: false
      t.string :name, null: false
      t.jsonb :configuration, null: false, default: {}
      t.timestamps
    end
    add_index :training_drills, :public_id, unique: true
    add_index :training_drills, [ :user_id, :name ], unique: true

    create_table :training_attempts do |t|
      t.references :training_session, null: false, foreign_key: true
      t.string :public_id, null: false
      t.uuid :idempotency_key, null: false
      t.integer :sequence, null: false
      t.string :target, null: false
      t.jsonb :result, null: false, default: {}
      t.integer :darts, null: false
      t.integer :hits, null: false, default: 0
      t.boolean :successful, null: false, default: false
      t.timestamps
    end
    add_index :training_attempts, :public_id, unique: true
    add_index :training_attempts, [ :training_session_id, :idempotency_key ], unique: true, name: "idx_training_attempts_idempotency"
    add_index :training_attempts, [ :training_session_id, :sequence ], unique: true

    add_check_constraint :training_attempts, "sequence > 0", name: "training_attempts_positive_sequence"
    add_check_constraint :training_attempts, "darts BETWEEN 1 AND 99", name: "training_attempts_valid_darts"
    add_check_constraint :training_attempts, "hits >= 0 AND hits <= darts", name: "training_attempts_valid_hits"
  end
end
