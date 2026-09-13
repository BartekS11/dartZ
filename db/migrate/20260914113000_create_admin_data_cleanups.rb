class CreateAdminDataCleanups < ActiveRecord::Migration[8.1]
  def change
    create_table :admin_data_cleanups do |t|
      t.string :public_id, null: false
      t.references :user, null: false, foreign_key: true
      t.jsonb :categories, null: false, default: []
      t.jsonb :counts, null: false, default: {}
      t.string :status, null: false, default: "cleared"
      t.datetime :cleared_at, null: false
      t.datetime :restored_at
      t.datetime :purged_at
      t.timestamps

      t.index :public_id, unique: true
      t.index [ :user_id, :created_at ]
      t.check_constraint "status IN ('cleared', 'restored', 'purged')", name: "admin_data_cleanups_valid_status"
      t.check_constraint "jsonb_typeof(categories) = 'array'", name: "admin_data_cleanups_categories_array"
      t.check_constraint "jsonb_array_length(categories) > 0", name: "admin_data_cleanups_categories_present"
      t.check_constraint "jsonb_typeof(counts) = 'object'", name: "admin_data_cleanups_counts_object"
    end

    create_table :admin_data_cleanup_events do |t|
      t.references :admin_data_cleanup, null: false, foreign_key: true
      t.references :admin_user, null: false, foreign_key: true
      t.references :user, null: false, foreign_key: true
      t.string :action, null: false
      t.jsonb :categories, null: false, default: []
      t.jsonb :counts, null: false, default: {}
      t.text :reason, null: false
      t.timestamps

      t.index [ :admin_data_cleanup_id, :created_at ], name: "index_admin_data_cleanup_events_on_cleanup_and_created_at"
      t.check_constraint "action IN ('clear', 'restore', 'purge')", name: "admin_data_cleanup_events_valid_action"
      t.check_constraint "length(trim(reason)) > 0", name: "admin_data_cleanup_events_reason_present"
      t.check_constraint "jsonb_typeof(categories) = 'array'", name: "admin_data_cleanup_events_categories_array"
      t.check_constraint "jsonb_typeof(counts) = 'object'", name: "admin_data_cleanup_events_counts_object"
    end

    add_reference :players, :admin_data_cleanup, foreign_key: true, index: true
    add_reference :training_sessions, :admin_data_cleanup, foreign_key: true, index: true
    add_reference :practice_plans, :admin_data_cleanup, foreign_key: true, index: true
    add_reference :training_drills, :admin_data_cleanup, foreign_key: true, index: true
    add_reference :dart_setups, :admin_data_cleanup, foreign_key: true, index: true
    add_reference :tournament_entries, :admin_data_cleanup, foreign_key: true, index: true
    add_reference :tournaments, :owner_admin_data_cleanup, foreign_key: { to_table: :admin_data_cleanups }, index: true

    remove_index :training_drills, name: "index_training_drills_on_user_id_and_name"
    add_index :training_drills, [ :user_id, :name ], unique: true,
      where: "admin_data_cleanup_id IS NULL", name: "index_visible_training_drills_on_user_and_name"

    remove_index :dart_setups, name: "index_dart_setups_on_user_id"
    add_index :dart_setups, :user_id, unique: true,
      where: "admin_data_cleanup_id IS NULL", name: "index_visible_dart_setups_on_user_id"
  end
end
