class CreateWebPushNotifications < ActiveRecord::Migration[8.1]
  def change
    create_table :push_subscriptions do |t|
      t.references :user, null: false, foreign_key: true
      t.string :public_id, null: false
      t.text :endpoint, null: false
      t.string :endpoint_digest, null: false
      t.text :p256dh, null: false
      t.text :auth, null: false
      t.string :device_label, null: false
      t.datetime :revoked_at
      t.datetime :last_success_at
      t.datetime :last_failure_at
      t.integer :failure_count, null: false, default: 0
      t.string :last_error_code
      t.timestamps
    end
    add_index :push_subscriptions, :public_id, unique: true
    add_index :push_subscriptions, :endpoint_digest, unique: true
    add_index :push_subscriptions, %i[user_id revoked_at created_at]
    add_check_constraint :push_subscriptions, "failure_count >= 0", name: "push_subscriptions_failure_count_nonnegative"

    create_table :notification_preferences do |t|
      t.references :user, null: false, foreign_key: true, index: { unique: true }
      t.boolean :friend_requests, null: false, default: true
      t.boolean :friendship_acceptance, null: false, default: true
      t.boolean :match_challenges, null: false, default: true
      t.boolean :tournament_round_ready, null: false, default: true
      t.timestamps
    end

    create_table :push_deliveries do |t|
      t.references :push_subscription, null: false, foreign_key: true
      t.string :category, null: false
      t.string :deduplication_key, null: false
      t.string :status, null: false, default: "pending"
      t.jsonb :payload, null: false, default: {}
      t.integer :attempts, null: false, default: 0
      t.datetime :delivered_at
      t.string :last_error_code
      t.timestamps
    end
    add_index :push_deliveries, %i[push_subscription_id deduplication_key], unique: true, name: "idx_push_deliveries_subscription_dedup"
    add_index :push_deliveries, %i[status created_at]
    add_check_constraint :push_deliveries, "category IN ('friend_requests', 'friendship_acceptance', 'match_challenges', 'tournament_round_ready', 'test')", name: "push_deliveries_category_valid"
    add_check_constraint :push_deliveries, "status IN ('pending', 'delivered', 'failed', 'cancelled')", name: "push_deliveries_status_valid"
    add_check_constraint :push_deliveries, "attempts >= 0", name: "push_deliveries_attempts_nonnegative"
  end
end
