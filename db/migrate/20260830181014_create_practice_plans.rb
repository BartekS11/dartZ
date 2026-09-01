class CreatePracticePlans < ActiveRecord::Migration[8.1]
  def change
    create_table :practice_plans do |t|
      t.references :user, null: false, foreign_key: true
      t.string :public_id, null: false
      t.string :title, null: false
      t.text :description
      t.string :plan_type, null: false
      t.string :status, null: false, default: "active"
      t.jsonb :recommendation_metadata, null: false, default: {}
      t.datetime :started_at, null: false
      t.datetime :completed_at

      t.timestamps
    end

    add_index :practice_plans, :public_id, unique: true
    add_index :practice_plans, [ :user_id, :status ]
    add_index :practice_plans, :plan_type

    create_table :practice_plan_tasks do |t|
      t.references :practice_plan, null: false, foreign_key: true
      t.string :title, null: false
      t.text :description
      t.string :training_mode, null: false
      t.integer :target_count, null: false, default: 1
      t.integer :progress_count, null: false, default: 0
      t.boolean :manual_completion_allowed, null: false, default: true
      t.integer :position, null: false, default: 1
      t.datetime :completed_at

      t.timestamps
    end

    add_index :practice_plan_tasks, [ :practice_plan_id, :position ]
    add_index :practice_plan_tasks, :training_mode

    create_table :practice_plan_task_events do |t|
      t.references :practice_plan_task, null: false, foreign_key: true
      t.references :training_session, foreign_key: true
      t.string :source, null: false
      t.integer :count, null: false, default: 1

      t.timestamps
    end

    add_index :practice_plan_task_events, [ :practice_plan_task_id, :training_session_id ], unique: true, name: "idx_practice_task_events_unique_training_session"
  end
end
