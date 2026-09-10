class CreateAdminDashboardRecords < ActiveRecord::Migration[8.1]
  def change
    create_table :admin_users do |t|
      t.string :email_address, null: false
      t.string :password_digest, null: false
      t.timestamps
    end
    add_index :admin_users, :email_address, unique: true

    create_table :admin_sessions do |t|
      t.references :admin_user, null: false, foreign_key: true
      t.string :ip_address
      t.string :user_agent
      t.datetime :expires_at, null: false
      t.timestamps
    end
    add_index :admin_sessions, :expires_at

    add_column :users, :manual_tier_override, :string
    add_check_constraint :users,
      "manual_tier_override IS NULL OR manual_tier_override IN ('free', 'premium', 'pro')",
      name: "users_manual_tier_override_valid"

    create_table :admin_tier_changes do |t|
      t.references :admin_user, null: false, foreign_key: true
      t.references :user, null: false, foreign_key: true
      t.string :action, null: false
      t.string :managed_tier, null: false
      t.string :previous_override
      t.string :new_override
      t.string :previous_effective_tier, null: false
      t.string :new_effective_tier, null: false
      t.text :reason
      t.timestamps
    end
    add_index :admin_tier_changes, [ :user_id, :created_at ]
  end
end
