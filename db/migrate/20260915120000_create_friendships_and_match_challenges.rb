class CreateFriendshipsAndMatchChallenges < ActiveRecord::Migration[8.1]
  def change
    change_table :users, bulk: true do |t|
      t.string :public_id
      t.string :friend_share_code
      t.boolean :discoverable_by_nickname, null: false, default: false
      t.string :friend_request_policy, null: false, default: "share_code_only"
      t.string :challenge_policy, null: false, default: "friends"
    end
    reversible do |direction|
      direction.up do
        select_values("SELECT id FROM users WHERE public_id IS NULL").each do |id|
          execute <<~SQL.squish
            UPDATE users
            SET public_id = #{quote(next_token("u_", 16))}, friend_share_code = #{quote(next_token("", 12).upcase)}
            WHERE id = #{quote(id)}
          SQL
        end
      end
    end
    change_column_null :users, :public_id, false
    change_column_null :users, :friend_share_code, false
    add_index :users, :public_id, unique: true
    add_index :users, :friend_share_code, unique: true
    add_check_constraint :users, "friend_request_policy IN ('anyone', 'share_code_only', 'nobody')", name: "users_friend_request_policy_valid"
    add_check_constraint :users, "challenge_policy IN ('friends', 'nobody')", name: "users_challenge_policy_valid"

    create_table :friendships do |t|
      t.references :user_low, null: false, foreign_key: { to_table: :users }
      t.references :user_high, null: false, foreign_key: { to_table: :users }
      t.string :public_id, null: false
      t.timestamps
    end
    add_index :friendships, :public_id, unique: true
    add_index :friendships, %i[user_low_id user_high_id], unique: true
    add_check_constraint :friendships, "user_low_id < user_high_id", name: "friendships_canonical_user_order"

    create_table :friend_requests do |t|
      t.references :requester, null: false, foreign_key: { to_table: :users }
      t.references :recipient, null: false, foreign_key: { to_table: :users }
      t.string :pair_key, null: false
      t.string :public_id, null: false
      t.string :status, null: false, default: "pending"
      t.datetime :resolved_at
      t.timestamps
    end
    add_index :friend_requests, :public_id, unique: true
    add_index :friend_requests, :pair_key, unique: true, where: "status = 'pending'", name: "idx_friend_requests_one_pending_pair"
    add_index :friend_requests, %i[recipient_id status created_at]
    add_check_constraint :friend_requests, "requester_id <> recipient_id", name: "friend_requests_distinct_users"
    add_check_constraint :friend_requests, "status IN ('pending', 'accepted', 'declined', 'cancelled')", name: "friend_requests_status_valid"

    create_table :user_blocks do |t|
      t.references :blocker, null: false, foreign_key: { to_table: :users }
      t.references :blocked, null: false, foreign_key: { to_table: :users }
      t.string :public_id, null: false
      t.timestamps
    end
    add_index :user_blocks, :public_id, unique: true
    add_index :user_blocks, %i[blocker_id blocked_id], unique: true
    add_check_constraint :user_blocks, "blocker_id <> blocked_id", name: "user_blocks_distinct_users"

    create_table :match_challenges do |t|
      t.references :challenger, null: false, foreign_key: { to_table: :users }
      t.references :challenged, null: false, foreign_key: { to_table: :users }
      t.references :match, null: false, foreign_key: true
      t.string :pair_key, null: false
      t.string :public_id, null: false
      t.string :status, null: false, default: "pending"
      t.datetime :expires_at, null: false
      t.datetime :resolved_at
      t.timestamps
    end
    add_index :match_challenges, :public_id, unique: true
    add_index :match_challenges, :pair_key, unique: true, where: "status = 'pending'", name: "idx_match_challenges_one_pending_pair"
    add_index :match_challenges, %i[challenged_id status created_at]
    add_index :match_challenges, :expires_at, where: "status = 'pending'"
    add_check_constraint :match_challenges, "challenger_id <> challenged_id", name: "match_challenges_distinct_users"
    add_check_constraint :match_challenges, "status IN ('pending', 'accepted', 'declined', 'cancelled', 'expired')", name: "match_challenges_status_valid"
  end

  private

  def next_token(prefix, length)
    alphabet = [ *"0".."9", *"A".."Z", *"a".."z" ]
    "#{prefix}#{Array.new(length) { alphabet[SecureRandom.random_number(alphabet.length)] }.join}"
  end
end
