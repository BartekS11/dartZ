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

ActiveRecord::Schema[8.1].define(version: 2026_07_08_120000) do
  # These are extensions that must be enabled in order to support this database
  enable_extension "pg_catalog.plpgsql"

  create_table "dart_setups", force: :cascade do |t|
    t.datetime "created_at", null: false
    t.string "manufacturer", default: "winmau", null: false
    t.integer "point_length_mm", null: false
    t.integer "shaft_length_mm", null: false
    t.string "shaft_type", null: false
    t.datetime "updated_at", null: false
    t.bigint "user_id", null: false
    t.decimal "weight_g", precision: 4, scale: 1, null: false
    t.index ["user_id"], name: "index_dart_setups_on_user_id", unique: true
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
    t.integer "starting_score"
    t.datetime "updated_at", null: false
    t.integer "winner_id"
    t.index ["match_id"], name: "index_legs_on_match_id"
    t.index ["match_set_id"], name: "index_legs_on_match_set_id"
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
    t.integer "starting_score", default: 501, null: false
    t.datetime "updated_at", null: false
    t.integer "winner_id"
    t.index ["guest_id"], name: "index_matches_on_guest_id"
    t.index ["guest_token"], name: "index_matches_on_guest_token", unique: true
    t.index ["invite_expires_at"], name: "index_matches_on_invite_expires_at"
    t.index ["invite_token"], name: "index_matches_on_invite_token", unique: true
  end

  create_table "players", force: :cascade do |t|
    t.boolean "bot", default: false, null: false
    t.integer "bot_level", default: 10
    t.datetime "created_at", null: false
    t.string "dart_setup_fingerprint"
    t.bigint "dart_setup_id"
    t.jsonb "dart_setup_snapshot", default: {}, null: false
    t.bigint "match_id"
    t.string "name"
    t.datetime "updated_at", null: false
    t.bigint "user_id"
    t.index ["dart_setup_id"], name: "index_players_on_dart_setup_id"
    t.index ["match_id"], name: "index_players_on_match_id"
    t.index ["user_id", "dart_setup_fingerprint"], name: "index_players_on_user_id_and_dart_setup_fingerprint"
    t.index ["user_id"], name: "index_players_on_user_id"
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
    t.decimal "buchholz", precision: 8, scale: 2, default: "0.0", null: false
    t.datetime "created_at", null: false
    t.integer "draws", default: 0, null: false
    t.string "group_name"
    t.integer "legs_against", default: 0, null: false
    t.integer "legs_for", default: 0, null: false
    t.integer "losses", default: 0, null: false
    t.string "name", null: false
    t.integer "points", default: 0, null: false
    t.integer "seed"
    t.string "status", default: "active", null: false
    t.bigint "tournament_id", null: false
    t.datetime "updated_at", null: false
    t.bigint "user_id"
    t.integer "wins", default: 0, null: false
    t.index ["access_token"], name: "index_tournament_entries_on_access_token", unique: true
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
    t.bigint "owner_user_id"
    t.integer "playoff_best_of_legs"
    t.integer "playoff_best_of_sets"
    t.boolean "playoff_double_in"
    t.boolean "playoff_double_out"
    t.string "playoff_mode", default: "single_elimination", null: false
    t.integer "playoff_qualifier_count"
    t.integer "playoff_starting_score"
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
    t.index ["owner_user_id"], name: "index_tournaments_on_owner_user_id"
    t.index ["share_token"], name: "index_tournaments_on_share_token", unique: true
  end

  create_table "turns", force: :cascade do |t|
    t.datetime "completed_at"
    t.datetime "created_at", null: false
    t.bigint "leg_id", null: false
    t.bigint "player_id", null: false
    t.integer "total_score"
    t.datetime "updated_at", null: false
    t.index ["leg_id"], name: "index_turns_on_leg_id"
    t.index ["player_id"], name: "index_turns_on_player_id"
  end

  create_table "users", force: :cascade do |t|
    t.string "account_tier", default: "free", null: false
    t.datetime "created_at", null: false
    t.string "email_address", null: false
    t.string "nickname"
    t.string "password_digest", null: false
    t.datetime "premium_access_expires_at"
    t.string "stripe_customer_id"
    t.string "stripe_subscription_id"
    t.datetime "updated_at", null: false
    t.index ["account_tier"], name: "index_users_on_account_tier"
    t.index ["email_address"], name: "index_users_on_email_address", unique: true
    t.index ["stripe_customer_id"], name: "index_users_on_stripe_customer_id", unique: true
    t.index ["stripe_subscription_id"], name: "index_users_on_stripe_subscription_id", unique: true
  end

  add_foreign_key "dart_setups", "users"
  add_foreign_key "leg_players", "legs"
  add_foreign_key "leg_players", "players"
  add_foreign_key "legs", "match_sets"
  add_foreign_key "legs", "matches"
  add_foreign_key "match_sets", "matches"
  add_foreign_key "players", "dart_setups"
  add_foreign_key "players", "matches"
  add_foreign_key "players", "users"
  add_foreign_key "sessions", "users"
  add_foreign_key "throws", "turns"
  add_foreign_key "tournament_entries", "tournaments"
  add_foreign_key "tournament_entries", "users"
  add_foreign_key "tournament_matches", "matches", column: "linked_match_id"
  add_foreign_key "tournament_matches", "tournament_entries", column: "away_entry_id"
  add_foreign_key "tournament_matches", "tournament_entries", column: "home_entry_id"
  add_foreign_key "tournament_matches", "tournament_entries", column: "winner_entry_id"
  add_foreign_key "tournament_matches", "tournament_rounds"
  add_foreign_key "tournament_matches", "tournaments"
  add_foreign_key "tournament_rounds", "tournaments"
  add_foreign_key "tournaments", "users", column: "owner_user_id"
  add_foreign_key "turns", "legs"
  add_foreign_key "turns", "players"
end
