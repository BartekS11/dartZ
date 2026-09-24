# This file is auto-generated from the current state of the database. Instead
# of editing this file, please use the migrations feature of Active Record to
# incrementally modify your database, and then regenerate this schema definition.
#
# This file is the source Rails uses to define your schema when running `bin/rails
# db:schema:load`. When creating a new database, `bin/rails db:schema:load` tends to
# be faster and is potentially less error prone than running all of your
# migrations from scratch. Old migrations may fail to apply correctly if those
# migrations use external dependencies or application code.
#
# It's strongly recommended that you check this file into your version control system.

ActiveRecord::Schema[8.1].define(version: 2026_09_17_120000) do
  # These are extensions that must be enabled in order to support this database
  enable_extension "pg_catalog.plpgsql"

  create_table "admin_data_cleanup_events", force: :cascade do |t|
    t.string "action", null: false
    t.bigint "admin_data_cleanup_id", null: false
    t.bigint "admin_user_id", null: false
    t.jsonb "categories", default: [], null: false
    t.jsonb "counts", default: {}, null: false
    t.datetime "created_at", null: false
    t.text "reason", null: false
    t.datetime "updated_at", null: false
    t.bigint "user_id", null: false
    t.index ["admin_data_cleanup_id", "created_at"], name: "index_admin_data_cleanup_events_on_cleanup_and_created_at"
    t.index ["admin_data_cleanup_id"], name: "index_admin_data_cleanup_events_on_admin_data_cleanup_id"
    t.index ["admin_user_id"], name: "index_admin_data_cleanup_events_on_admin_user_id"
    t.index ["user_id"], name: "index_admin_data_cleanup_events_on_user_id"
    t.check_constraint "action::text = ANY (ARRAY['clear'::character varying, 'restore'::character varying, 'purge'::character varying]::text[])", name: "admin_data_cleanup_events_valid_action"
    t.check_constraint "jsonb_typeof(categories) = 'array'::text", name: "admin_data_cleanup_events_categories_array"
    t.check_constraint "jsonb_typeof(counts) = 'object'::text", name: "admin_data_cleanup_events_counts_object"
    t.check_constraint "length(TRIM(BOTH FROM reason)) > 0", name: "admin_data_cleanup_events_reason_present"
  end

  create_table "admin_data_cleanups", force: :cascade do |t|
    t.jsonb "categories", default: [], null: false
    t.datetime "cleared_at", null: false
    t.jsonb "counts", default: {}, null: false
    t.datetime "created_at", null: false
    t.string "public_id", null: false
    t.datetime "purged_at"
    t.datetime "restored_at"
    t.string "status", default: "cleared", null: false
    t.datetime "updated_at", null: false
    t.bigint "user_id", null: false
    t.index ["public_id"], name: "index_admin_data_cleanups_on_public_id", unique: true
    t.index ["user_id", "created_at"], name: "index_admin_data_cleanups_on_user_id_and_created_at"
    t.index ["user_id"], name: "index_admin_data_cleanups_on_user_id"
    t.check_constraint "jsonb_array_length(categories) > 0", name: "admin_data_cleanups_categories_present"
    t.check_constraint "jsonb_typeof(categories) = 'array'::text", name: "admin_data_cleanups_categories_array"
    t.check_constraint "jsonb_typeof(counts) = 'object'::text", name: "admin_data_cleanups_counts_object"
    t.check_constraint "status::text = ANY (ARRAY['cleared'::character varying, 'restored'::character varying, 'purged'::character varying]::text[])", name: "admin_data_cleanups_valid_status"
  end

  create_table "admin_sessions", force: :cascade do |t|
    t.bigint "admin_user_id", null: false
    t.datetime "created_at", null: false
    t.datetime "expires_at", null: false
    t.string "ip_address"
    t.datetime "updated_at", null: false
    t.string "user_agent"
    t.index ["admin_user_id"], name: "index_admin_sessions_on_admin_user_id"
    t.index ["expires_at"], name: "index_admin_sessions_on_expires_at"
  end

  create_table "admin_tier_changes", force: :cascade do |t|
    t.string "action", null: false
    t.bigint "admin_user_id", null: false
    t.datetime "created_at", null: false
    t.string "managed_tier", null: false
    t.string "new_effective_tier", null: false
    t.string "new_override"
    t.string "previous_effective_tier", null: false
    t.string "previous_override"
    t.text "reason"
    t.datetime "updated_at", null: false
    t.bigint "user_id", null: false
    t.index ["admin_user_id"], name: "index_admin_tier_changes_on_admin_user_id"
    t.index ["user_id", "created_at"], name: "index_admin_tier_changes_on_user_id_and_created_at"
    t.index ["user_id"], name: "index_admin_tier_changes_on_user_id"
  end

  create_table "admin_users", force: :cascade do |t|
    t.datetime "created_at", null: false
    t.string "email_address", null: false
    t.string "password_digest", null: false
    t.datetime "updated_at", null: false
    t.index ["email_address"], name: "index_admin_users_on_email_address", unique: true
  end

  create_table "dart_setups", force: :cascade do |t|
    t.bigint "admin_data_cleanup_id"
    t.datetime "created_at", null: false
    t.string "manufacturer", default: "winmau", null: false
    t.integer "point_length_mm", null: false
    t.integer "shaft_length_mm", null: false
    t.string "shaft_type", null: false
    t.datetime "updated_at", null: false
    t.bigint "user_id", null: false
    t.decimal "weight_g", precision: 4, scale: 1, null: false
    t.index ["admin_data_cleanup_id"], name: "index_dart_setups_on_admin_data_cleanup_id"
    t.index ["user_id"], name: "index_visible_dart_setups_on_user_id", unique: true, where: "(admin_data_cleanup_id IS NULL)"
  end

  create_table "friend_requests", force: :cascade do |t|
    t.datetime "created_at", null: false
    t.string "pair_key", null: false
    t.string "public_id", null: false
    t.bigint "recipient_id", null: false
    t.bigint "requester_id", null: false
    t.datetime "resolved_at"
    t.string "status", default: "pending", null: false
    t.datetime "updated_at", null: false
    t.index ["pair_key"], name: "idx_friend_requests_one_pending_pair", unique: true, where: "((status)::text = 'pending'::text)"
    t.index ["public_id"], name: "index_friend_requests_on_public_id", unique: true
    t.index ["recipient_id", "status", "created_at"], name: "idx_on_recipient_id_status_created_at_1b323de6a3"
    t.index ["recipient_id"], name: "index_friend_requests_on_recipient_id"
    t.index ["requester_id", "status", "created_at"], name: "index_friend_requests_outgoing_status_created"
    t.index ["requester_id"], name: "index_friend_requests_on_requester_id"
    t.check_constraint "requester_id <> recipient_id", name: "friend_requests_distinct_users"
    t.check_constraint "status::text = ANY (ARRAY['pending'::character varying, 'accepted'::character varying, 'declined'::character varying, 'cancelled'::character varying]::text[])", name: "friend_requests_status_valid"
  end

  create_table "friendships", force: :cascade do |t|
    t.datetime "created_at", null: false
    t.string "public_id", null: false
    t.datetime "updated_at", null: false
    t.bigint "user_high_id", null: false
    t.bigint "user_low_id", null: false
    t.index ["public_id"], name: "index_friendships_on_public_id", unique: true
    t.index ["user_high_id"], name: "index_friendships_on_user_high_id"
    t.index ["user_low_id", "user_high_id"], name: "index_friendships_on_user_low_id_and_user_high_id", unique: true
    t.index ["user_low_id"], name: "index_friendships_on_user_low_id"
    t.check_constraint "user_low_id < user_high_id", name: "friendships_canonical_user_order"
  end

  create_table "leg_players", force: :cascade do |t|
    t.datetime "created_at", null: false
    t.integer "current_score"
    t.boolean "has_doubled_in", default: false, null: false
    t.bigint "leg_id", null: false
    t.bigint "player_id", null: false
    t.integer "score"
    t.integer "starting_score"
    t.datetime "updated_at", null: false
    t.index ["leg_id", "player_id"], name: "index_leg_players_on_leg_id_and_player_id", unique: true
    t.index ["leg_id"], name: "index_leg_players_on_leg_id"
    t.index ["player_id"], name: "index_leg_players_on_player_id"
  end

  create_table "legs", force: :cascade do |t|
    t.integer "checkout_throws"
    t.datetime "created_at", null: false
    t.datetime "finished_at"
    t.bigint "match_id", null: false
    t.bigint "match_set_id"
    t.string "public_id", null: false
    t.integer "starting_score"
    t.datetime "updated_at", null: false
    t.integer "winner_id"
    t.index ["match_id"], name: "index_legs_on_match_id"
    t.index ["match_set_id"], name: "index_legs_on_match_set_id"
    t.index ["public_id"], name: "index_legs_on_public_id", unique: true
  end

  create_table "match_challenges", force: :cascade do |t|
    t.bigint "challenged_id", null: false
    t.bigint "challenger_id", null: false
    t.datetime "created_at", null: false
    t.datetime "expires_at", null: false
    t.bigint "match_id", null: false
    t.string "pair_key", null: false
    t.string "public_id", null: false
    t.datetime "resolved_at"
    t.string "status", default: "pending", null: false
    t.datetime "updated_at", null: false
    t.index ["challenged_id", "status", "created_at"], name: "idx_on_challenged_id_status_created_at_d8579e6ae0"
    t.index ["challenged_id"], name: "index_match_challenges_on_challenged_id"
    t.index ["challenger_id", "status", "created_at"], name: "index_match_challenges_outgoing_status_created"
    t.index ["challenger_id"], name: "index_match_challenges_on_challenger_id"
    t.index ["expires_at"], name: "index_match_challenges_on_expires_at", where: "((status)::text = 'pending'::text)"
    t.index ["match_id"], name: "index_match_challenges_on_match_id"
    t.index ["pair_key"], name: "idx_match_challenges_one_pending_pair", unique: true, where: "((status)::text = 'pending'::text)"
    t.index ["public_id"], name: "index_match_challenges_on_public_id", unique: true
    t.check_constraint "challenger_id <> challenged_id", name: "match_challenges_distinct_users"
    t.check_constraint "status::text = ANY (ARRAY['pending'::character varying, 'accepted'::character varying, 'declined'::character varying, 'cancelled'::character varying, 'expired'::character varying]::text[])", name: "match_challenges_status_valid"
  end

  create_table "match_sets", force: :cascade do |t|
    t.datetime "created_at", null: false
    t.datetime "finished_at"
    t.bigint "match_id", null: false
    t.datetime "updated_at", null: false
    t.integer "winner_id"
    t.index ["match_id"], name: "index_match_sets_on_match_id"
  end

  create_table "matches", force: :cascade do |t|
    t.integer "best_of_legs", default: 1, null: false
    t.integer "best_of_sets", default: 1, null: false
    t.datetime "created_at", null: false
    t.boolean "double_in", default: false, null: false
    t.boolean "double_out", default: true, null: false
    t.datetime "finished_at"
    t.string "guest_id"
    t.string "guest_token"
    t.datetime "invite_cancelled_at"
    t.datetime "invite_created_at"
    t.datetime "invite_expires_at"
    t.datetime "invite_joined_at"
    t.string "invite_token"
    t.string "match_identifier"
    t.boolean "player_display_reversed", default: false, null: false
    t.string "public_id", null: false
    t.integer "starting_player_position", default: 1, null: false
    t.integer "starting_score", default: 501, null: false
    t.datetime "updated_at", null: false
    t.integer "winner_id"
    t.index ["guest_id"], name: "index_matches_on_guest_id"
    t.index ["guest_token"], name: "index_matches_on_guest_token", unique: true
    t.index ["invite_expires_at"], name: "index_matches_on_invite_expires_at"
    t.index ["invite_token"], name: "index_matches_on_invite_token", unique: true
    t.index ["public_id"], name: "index_matches_on_public_id", unique: true
  end

  create_table "notification_preferences", force: :cascade do |t|
    t.datetime "created_at", null: false
    t.boolean "friend_requests", default: true, null: false
    t.boolean "friendship_acceptance", default: true, null: false
    t.boolean "match_challenges", default: true, null: false
    t.boolean "tournament_round_ready", default: true, null: false
    t.datetime "updated_at", null: false
    t.bigint "user_id", null: false
    t.index ["user_id"], name: "index_notification_preferences_on_user_id", unique: true
  end

  create_table "players", force: :cascade do |t|
    t.bigint "admin_data_cleanup_id"
    t.boolean "bot", default: false, null: false
    t.integer "bot_level", default: 10
    t.datetime "created_at", null: false
    t.string "dart_setup_fingerprint"
    t.bigint "dart_setup_id"
    t.jsonb "dart_setup_snapshot", default: {}, null: false
    t.bigint "match_id"
    t.string "name"
    t.string "public_id", null: false
    t.datetime "updated_at", null: false
    t.bigint "user_id"
    t.index ["admin_data_cleanup_id"], name: "index_players_on_admin_data_cleanup_id"
    t.index ["dart_setup_id"], name: "index_players_on_dart_setup_id"
    t.index ["match_id"], name: "index_players_on_match_id"
    t.index ["public_id"], name: "index_players_on_public_id", unique: true
    t.index ["user_id", "dart_setup_fingerprint"], name: "index_players_on_user_id_and_dart_setup_fingerprint"
    t.index ["user_id"], name: "index_players_on_user_id"
  end

  create_table "practice_plan_task_events", force: :cascade do |t|
    t.integer "count", default: 1, null: false
    t.datetime "created_at", null: false
    t.bigint "practice_plan_task_id", null: false
    t.string "source", null: false
    t.bigint "training_session_id"
    t.datetime "updated_at", null: false
    t.index ["practice_plan_task_id", "training_session_id"], name: "idx_practice_task_events_unique_training_session", unique: true
    t.index ["practice_plan_task_id"], name: "index_practice_plan_task_events_on_practice_plan_task_id"
    t.index ["training_session_id"], name: "index_practice_plan_task_events_on_training_session_id"
  end

  create_table "practice_plan_tasks", force: :cascade do |t|
    t.datetime "completed_at"
    t.datetime "created_at", null: false
    t.text "description"
    t.boolean "manual_completion_allowed", default: true, null: false
    t.integer "position", default: 1, null: false
    t.bigint "practice_plan_id", null: false
    t.integer "progress_count", default: 0, null: false
    t.integer "target_count", default: 1, null: false
    t.string "title", null: false
    t.string "training_mode", null: false
    t.datetime "updated_at", null: false
    t.index ["practice_plan_id", "position"], name: "index_practice_plan_tasks_on_practice_plan_id_and_position"
    t.index ["practice_plan_id"], name: "index_practice_plan_tasks_on_practice_plan_id"
    t.index ["training_mode"], name: "index_practice_plan_tasks_on_training_mode"
  end

  create_table "practice_plans", force: :cascade do |t|
    t.bigint "admin_data_cleanup_id"
    t.datetime "completed_at"
    t.datetime "created_at", null: false
    t.text "description"
    t.string "plan_type", null: false
    t.string "public_id", null: false
    t.jsonb "recommendation_metadata", default: {}, null: false
    t.datetime "started_at", null: false
    t.string "status", default: "active", null: false
    t.string "title", null: false
    t.datetime "updated_at", null: false
    t.bigint "user_id", null: false
    t.index ["admin_data_cleanup_id"], name: "index_practice_plans_on_admin_data_cleanup_id"
    t.index ["plan_type"], name: "index_practice_plans_on_plan_type"
    t.index ["public_id"], name: "index_practice_plans_on_public_id", unique: true
    t.index ["user_id", "status"], name: "index_practice_plans_on_user_id_and_status"
    t.index ["user_id"], name: "index_practice_plans_on_user_id"
  end

  create_table "push_deliveries", force: :cascade do |t|
    t.integer "attempts", default: 0, null: false
    t.string "category", null: false
    t.datetime "created_at", null: false
    t.string "deduplication_key", null: false
    t.datetime "delivered_at"
    t.string "last_error_code"
    t.jsonb "payload", default: {}, null: false
    t.bigint "push_subscription_id", null: false
    t.string "status", default: "pending", null: false
    t.datetime "updated_at", null: false
    t.index ["push_subscription_id", "deduplication_key"], name: "idx_push_deliveries_subscription_dedup", unique: true
    t.index ["push_subscription_id"], name: "index_push_deliveries_on_push_subscription_id"
    t.index ["status", "created_at"], name: "index_push_deliveries_on_status_and_created_at"
    t.check_constraint "attempts >= 0", name: "push_deliveries_attempts_nonnegative"
    t.check_constraint "category::text = ANY (ARRAY['friend_requests'::character varying, 'friendship_acceptance'::character varying, 'match_challenges'::character varying, 'tournament_round_ready'::character varying, 'test'::character varying]::text[])", name: "push_deliveries_category_valid"
    t.check_constraint "status::text = ANY (ARRAY['pending'::character varying, 'delivered'::character varying, 'failed'::character varying, 'cancelled'::character varying]::text[])", name: "push_deliveries_status_valid"
  end

  create_table "push_subscriptions", force: :cascade do |t|
    t.text "auth", null: false
    t.datetime "created_at", null: false
    t.string "device_label", null: false
    t.text "endpoint", null: false
    t.string "endpoint_digest", null: false
    t.integer "failure_count", default: 0, null: false
    t.string "last_error_code"
    t.datetime "last_failure_at"
    t.datetime "last_success_at"
    t.text "p256dh", null: false
    t.string "public_id", null: false
    t.datetime "revoked_at"
    t.datetime "updated_at", null: false
    t.bigint "user_id", null: false
    t.index ["endpoint_digest"], name: "index_push_subscriptions_on_endpoint_digest", unique: true
    t.index ["public_id"], name: "index_push_subscriptions_on_public_id", unique: true
    t.index ["user_id", "revoked_at", "created_at"], name: "idx_on_user_id_revoked_at_created_at_aaf5da6e2b"
    t.index ["user_id"], name: "index_push_subscriptions_on_user_id"
    t.check_constraint "failure_count >= 0", name: "push_subscriptions_failure_count_nonnegative"
  end

  create_table "sessions", force: :cascade do |t|
    t.datetime "created_at", null: false
    t.string "ip_address"
    t.datetime "updated_at", null: false
    t.string "user_agent"
    t.bigint "user_id", null: false
    t.index ["user_id"], name: "index_sessions_on_user_id"
  end

  create_table "throws", force: :cascade do |t|
    t.datetime "created_at", null: false
    t.integer "multiplier"
    t.integer "segment"
    t.bigint "turn_id", null: false
    t.datetime "updated_at", null: false
    t.index ["turn_id"], name: "index_throws_on_turn_id"
  end

  create_table "tournament_entries", force: :cascade do |t|
    t.string "access_token", null: false
    t.bigint "admin_data_cleanup_id"
    t.decimal "buchholz", precision: 8, scale: 2, default: "0.0", null: false
    t.datetime "created_at", null: false
    t.integer "draws", default: 0, null: false
    t.string "group_name"
    t.integer "legs_against", default: 0, null: false
    t.integer "legs_for", default: 0, null: false
    t.integer "losses", default: 0, null: false
    t.string "name", null: false
    t.integer "points", default: 0, null: false
    t.string "public_id", null: false
    t.integer "seed"
    t.string "status", default: "active", null: false
    t.bigint "tournament_id", null: false
    t.datetime "updated_at", null: false
    t.bigint "user_id"
    t.integer "wins", default: 0, null: false
    t.index ["access_token"], name: "index_tournament_entries_on_access_token", unique: true
    t.index ["admin_data_cleanup_id"], name: "index_tournament_entries_on_admin_data_cleanup_id"
    t.index ["public_id"], name: "index_tournament_entries_on_public_id", unique: true
    t.index ["tournament_id", "name"], name: "index_tournament_entries_on_tournament_id_and_name", unique: true
    t.index ["tournament_id"], name: "index_tournament_entries_on_tournament_id"
    t.index ["user_id"], name: "index_tournament_entries_on_user_id"
  end

  create_table "tournament_matches", force: :cascade do |t|
    t.bigint "away_entry_id"
    t.integer "away_legs", default: 0, null: false
    t.integer "away_sets", default: 0, null: false
    t.integer "best_of_legs", default: 1, null: false
    t.integer "best_of_sets", default: 1, null: false
    t.string "bracket"
    t.boolean "bye", default: false, null: false
    t.datetime "completed_at"
    t.datetime "created_at", null: false
    t.boolean "double_in", default: false, null: false
    t.boolean "double_out", default: true, null: false
    t.bigint "home_entry_id"
    t.integer "home_legs", default: 0, null: false
    t.integer "home_sets", default: 0, null: false
    t.bigint "linked_match_id"
    t.integer "position"
    t.string "public_id", null: false
    t.jsonb "settings", default: {}, null: false
    t.string "source", default: "generated", null: false
    t.integer "starting_score", default: 501, null: false
    t.string "status", default: "pending", null: false
    t.bigint "tournament_id", null: false
    t.bigint "tournament_round_id", null: false
    t.datetime "updated_at", null: false
    t.bigint "winner_entry_id"
    t.index ["away_entry_id"], name: "index_tournament_matches_on_away_entry_id"
    t.index ["home_entry_id"], name: "index_tournament_matches_on_home_entry_id"
    t.index ["linked_match_id"], name: "index_tournament_matches_on_linked_match_id"
    t.index ["public_id"], name: "index_tournament_matches_on_public_id", unique: true
    t.index ["tournament_id"], name: "index_tournament_matches_on_tournament_id"
    t.index ["tournament_round_id", "position"], name: "index_tournament_matches_on_tournament_round_id_and_position", unique: true
    t.index ["tournament_round_id"], name: "index_tournament_matches_on_tournament_round_id"
    t.index ["winner_entry_id"], name: "index_tournament_matches_on_winner_entry_id"
  end

  create_table "tournament_rounds", force: :cascade do |t|
    t.string "bracket"
    t.datetime "created_at", null: false
    t.string "group_name"
    t.string "name", null: false
    t.integer "number", null: false
    t.jsonb "settings", default: {}, null: false
    t.string "stage_type", null: false
    t.string "status", default: "pending", null: false
    t.bigint "tournament_id", null: false
    t.datetime "updated_at", null: false
    t.index ["tournament_id", "number", "bracket", "group_name"], name: "idx_tournament_rounds_uniqueness"
    t.index ["tournament_id"], name: "index_tournament_rounds_on_tournament_id"
  end

  create_table "tournaments", force: :cascade do |t|
    t.string "admin_token", null: false
    t.boolean "allow_wildcards", default: false, null: false
    t.boolean "auto_advance", default: true, null: false
    t.integer "best_of_legs", default: 1, null: false
    t.integer "best_of_sets", default: 1, null: false
    t.boolean "bronze_match", default: false, null: false
    t.datetime "created_at", null: false
    t.boolean "double_in", default: false, null: false
    t.boolean "double_out", default: true, null: false
    t.integer "final_best_of_legs"
    t.string "format_type", null: false
    t.integer "group_count"
    t.string "join_token", null: false
    t.boolean "manual_advance_allowed", default: true, null: false
    t.bigint "owner_admin_data_cleanup_id"
    t.bigint "owner_user_id"
    t.integer "playoff_best_of_legs"
    t.integer "playoff_best_of_sets"
    t.boolean "playoff_double_in"
    t.boolean "playoff_double_out"
    t.string "playoff_mode", default: "single_elimination", null: false
    t.integer "playoff_qualifier_count"
    t.integer "playoff_starting_score"
    t.string "public_id", null: false
    t.datetime "published_at"
    t.integer "qualifiers_per_group"
    t.string "seeding_mode", default: "auto", null: false
    t.integer "semifinal_best_of_legs"
    t.jsonb "settings", default: {}, null: false
    t.string "share_token", null: false
    t.integer "starting_score", default: 501, null: false
    t.string "status", default: "draft", null: false
    t.integer "swiss_round_count"
    t.string "title", null: false
    t.datetime "updated_at", null: false
    t.string "visibility", default: "public_guest", null: false
    t.index ["admin_token"], name: "index_tournaments_on_admin_token", unique: true
    t.index ["join_token"], name: "index_tournaments_on_join_token", unique: true
    t.index ["owner_admin_data_cleanup_id"], name: "index_tournaments_on_owner_admin_data_cleanup_id"
    t.index ["owner_user_id"], name: "index_tournaments_on_owner_user_id"
    t.index ["public_id"], name: "index_tournaments_on_public_id", unique: true
    t.index ["share_token"], name: "index_tournaments_on_share_token", unique: true
  end

  create_table "training_attempts", force: :cascade do |t|
    t.datetime "created_at", null: false
    t.integer "darts", null: false
    t.integer "hits", default: 0, null: false
    t.uuid "idempotency_key", null: false
    t.string "public_id", null: false
    t.jsonb "response", default: {}, null: false
    t.jsonb "result", default: {}, null: false
    t.integer "sequence", null: false
    t.boolean "successful", default: false, null: false
    t.string "target", null: false
    t.bigint "training_session_id", null: false
    t.datetime "updated_at", null: false
    t.index ["public_id"], name: "index_training_attempts_on_public_id", unique: true
    t.index ["training_session_id", "idempotency_key"], name: "idx_training_attempts_idempotency", unique: true
    t.index ["training_session_id", "sequence"], name: "index_training_attempts_on_training_session_id_and_sequence", unique: true
    t.index ["training_session_id"], name: "index_training_attempts_on_training_session_id"
    t.check_constraint "darts >= 1 AND darts <= 99", name: "training_attempts_valid_darts"
    t.check_constraint "hits >= 0 AND hits <= darts", name: "training_attempts_valid_hits"
    t.check_constraint "jsonb_typeof(response) = 'object'::text", name: "training_attempts_response_object"
    t.check_constraint "jsonb_typeof(result) = 'object'::text", name: "training_attempts_result_object"
    t.check_constraint "sequence > 0", name: "training_attempts_positive_sequence"
  end

  create_table "training_drills", force: :cascade do |t|
    t.bigint "admin_data_cleanup_id"
    t.jsonb "configuration", default: {}, null: false
    t.datetime "created_at", null: false
    t.string "name", null: false
    t.string "public_id", null: false
    t.datetime "updated_at", null: false
    t.bigint "user_id", null: false
    t.index ["admin_data_cleanup_id"], name: "index_training_drills_on_admin_data_cleanup_id"
    t.index ["public_id"], name: "index_training_drills_on_public_id", unique: true
    t.index ["user_id", "name"], name: "index_visible_training_drills_on_user_and_name", unique: true, where: "(admin_data_cleanup_id IS NULL)"
    t.index ["user_id"], name: "index_training_drills_on_user_id"
    t.check_constraint "jsonb_typeof(configuration) = 'object'::text", name: "training_drills_configuration_object"
  end

  create_table "training_sessions", force: :cascade do |t|
    t.datetime "abandoned_at"
    t.bigint "admin_data_cleanup_id"
    t.datetime "completed_at"
    t.jsonb "configuration", default: {}, null: false
    t.datetime "created_at", null: false
    t.integer "current_target_index", default: 0, null: false
    t.integer "hits", default: 0, null: false
    t.integer "misses", default: 0, null: false
    t.string "mode", null: false
    t.string "public_id", null: false
    t.integer "score"
    t.datetime "started_at", null: false
    t.jsonb "state", default: {}, null: false
    t.string "status", default: "active", null: false
    t.jsonb "target_stats", default: [], null: false
    t.integer "total_darts", default: 0, null: false
    t.datetime "updated_at", null: false
    t.bigint "user_id", null: false
    t.index ["admin_data_cleanup_id"], name: "index_training_sessions_on_admin_data_cleanup_id"
    t.index ["public_id"], name: "index_training_sessions_on_public_id", unique: true
    t.index ["user_id", "created_at"], name: "index_training_sessions_on_user_id_and_created_at"
    t.index ["user_id", "status"], name: "index_training_sessions_on_user_id_and_status"
    t.index ["user_id"], name: "index_training_sessions_on_user_id"
    t.check_constraint "jsonb_typeof(configuration) = 'object'::text", name: "training_sessions_configuration_object"
    t.check_constraint "jsonb_typeof(state) = 'object'::text", name: "training_sessions_state_object"
  end

  create_table "turns", force: :cascade do |t|
    t.datetime "completed_at"
    t.datetime "created_at", null: false
    t.bigint "leg_id", null: false
    t.bigint "player_id", null: false
    t.string "public_id", null: false
    t.integer "total_score"
    t.datetime "updated_at", null: false
    t.index ["leg_id"], name: "index_turns_on_leg_id"
    t.index ["player_id"], name: "index_turns_on_player_id"
    t.index ["public_id"], name: "index_turns_on_public_id", unique: true
  end

  create_table "user_blocks", force: :cascade do |t|
    t.bigint "blocked_id", null: false
    t.bigint "blocker_id", null: false
    t.datetime "created_at", null: false
    t.string "public_id", null: false
    t.datetime "updated_at", null: false
    t.index ["blocked_id"], name: "index_user_blocks_on_blocked_id"
    t.index ["blocker_id", "blocked_id"], name: "index_user_blocks_on_blocker_id_and_blocked_id", unique: true
    t.index ["blocker_id", "created_at"], name: "index_user_blocks_on_blocker_created"
    t.index ["blocker_id"], name: "index_user_blocks_on_blocker_id"
    t.index ["public_id"], name: "index_user_blocks_on_public_id", unique: true
    t.check_constraint "blocker_id <> blocked_id", name: "user_blocks_distinct_users"
  end

  create_table "users", force: :cascade do |t|
    t.string "account_tier", default: "free", null: false
    t.string "challenge_policy", default: "friends", null: false
    t.datetime "created_at", null: false
    t.boolean "discoverable_by_nickname", default: false, null: false
    t.string "email_address", null: false
    t.string "friend_request_policy", default: "share_code_only", null: false
    t.string "friend_share_code", null: false
    t.string "locale", default: "en", null: false
    t.string "manual_tier_override"
    t.string "nickname"
    t.integer "onboarding_guide_version", default: 0, null: false
    t.string "password_digest", null: false
    t.datetime "premium_access_expires_at"
    t.string "public_id", null: false
    t.string "stripe_customer_id"
    t.string "stripe_price_id"
    t.string "stripe_subscription_id"
    t.string "stripe_subscription_status"
    t.string "subscription_currency"
    t.datetime "updated_at", null: false
    t.index "lower((nickname)::text)", name: "index_discoverable_users_on_lower_nickname", where: "(discoverable_by_nickname = true)"
    t.index ["account_tier"], name: "index_users_on_account_tier"
    t.index ["email_address"], name: "index_users_on_email_address", unique: true
    t.index ["friend_share_code"], name: "index_users_on_friend_share_code", unique: true
    t.index ["public_id"], name: "index_users_on_public_id", unique: true
    t.index ["stripe_customer_id"], name: "index_users_on_stripe_customer_id", unique: true
    t.index ["stripe_subscription_id"], name: "index_users_on_stripe_subscription_id", unique: true
    t.check_constraint "challenge_policy::text = ANY (ARRAY['friends'::character varying, 'nobody'::character varying]::text[])", name: "users_challenge_policy_valid"
    t.check_constraint "friend_request_policy::text = ANY (ARRAY['anyone'::character varying, 'share_code_only'::character varying, 'nobody'::character varying]::text[])", name: "users_friend_request_policy_valid"
    t.check_constraint "manual_tier_override IS NULL OR (manual_tier_override::text = ANY (ARRAY['free'::character varying, 'premium'::character varying, 'pro'::character varying]::text[]))", name: "users_manual_tier_override_valid"
  end

  add_foreign_key "admin_data_cleanup_events", "admin_data_cleanups"
  add_foreign_key "admin_data_cleanup_events", "admin_users"
  add_foreign_key "admin_data_cleanup_events", "users"
  add_foreign_key "admin_data_cleanups", "users"
  add_foreign_key "admin_sessions", "admin_users"
  add_foreign_key "admin_tier_changes", "admin_users"
  add_foreign_key "admin_tier_changes", "users"
  add_foreign_key "dart_setups", "admin_data_cleanups"
  add_foreign_key "dart_setups", "users"
  add_foreign_key "friend_requests", "users", column: "recipient_id"
  add_foreign_key "friend_requests", "users", column: "requester_id"
  add_foreign_key "friendships", "users", column: "user_high_id"
  add_foreign_key "friendships", "users", column: "user_low_id"
  add_foreign_key "leg_players", "legs"
  add_foreign_key "leg_players", "players"
  add_foreign_key "legs", "match_sets"
  add_foreign_key "legs", "matches"
  add_foreign_key "match_challenges", "matches"
  add_foreign_key "match_challenges", "users", column: "challenged_id"
  add_foreign_key "match_challenges", "users", column: "challenger_id"
  add_foreign_key "match_sets", "matches"
  add_foreign_key "notification_preferences", "users"
  add_foreign_key "players", "admin_data_cleanups"
  add_foreign_key "players", "dart_setups"
  add_foreign_key "players", "matches"
  add_foreign_key "players", "users"
  add_foreign_key "practice_plan_task_events", "practice_plan_tasks"
  add_foreign_key "practice_plan_task_events", "training_sessions"
  add_foreign_key "practice_plan_tasks", "practice_plans"
  add_foreign_key "practice_plans", "admin_data_cleanups"
  add_foreign_key "practice_plans", "users"
  add_foreign_key "push_deliveries", "push_subscriptions"
  add_foreign_key "push_subscriptions", "users"
  add_foreign_key "sessions", "users"
  add_foreign_key "throws", "turns"
  add_foreign_key "tournament_entries", "admin_data_cleanups"
  add_foreign_key "tournament_entries", "tournaments"
  add_foreign_key "tournament_entries", "users"
  add_foreign_key "tournament_matches", "matches", column: "linked_match_id"
  add_foreign_key "tournament_matches", "tournament_entries", column: "away_entry_id"
  add_foreign_key "tournament_matches", "tournament_entries", column: "home_entry_id"
  add_foreign_key "tournament_matches", "tournament_entries", column: "winner_entry_id"
  add_foreign_key "tournament_matches", "tournament_rounds"
  add_foreign_key "tournament_matches", "tournaments"
  add_foreign_key "tournament_rounds", "tournaments"
  add_foreign_key "tournaments", "admin_data_cleanups", column: "owner_admin_data_cleanup_id"
  add_foreign_key "tournaments", "users", column: "owner_user_id"
  add_foreign_key "training_attempts", "training_sessions"
  add_foreign_key "training_drills", "admin_data_cleanups"
  add_foreign_key "training_drills", "users"
  add_foreign_key "training_sessions", "admin_data_cleanups"
  add_foreign_key "training_sessions", "users"
  add_foreign_key "turns", "legs"
  add_foreign_key "turns", "players"
  add_foreign_key "user_blocks", "users", column: "blocked_id"
  add_foreign_key "user_blocks", "users", column: "blocker_id"
end
