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

ActiveRecord::Schema[8.1].define(version: 2026_01_16_145727) do
  # These are extensions that must be enabled in order to support this database
  enable_extension "pg_catalog.plpgsql"

  create_table "leg_players", force: :cascade do |t|
    t.datetime "created_at", null: false
    t.integer "current_score"
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
    t.datetime "created_at", null: false
    t.datetime "finished_at"
    t.bigint "match_id", null: false
    t.integer "starting_score"
    t.datetime "updated_at", null: false
    t.index ["match_id"], name: "index_legs_on_match_id"
  end

  create_table "matches", force: :cascade do |t|
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
  end

  create_table "players", force: :cascade do |t|
    t.datetime "created_at", null: false
    t.bigint "match_id"
    t.string "name"
    t.datetime "updated_at", null: false
    t.bigint "user_id"
    t.index ["match_id"], name: "index_players_on_match_id"
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

  create_table "turns", force: :cascade do |t|
    t.datetime "created_at", null: false
    t.bigint "leg_id", null: false
    t.bigint "player_id", null: false
    t.datetime "updated_at", null: false
    t.index ["leg_id"], name: "index_turns_on_leg_id"
    t.index ["player_id"], name: "index_turns_on_player_id"
  end

  create_table "users", force: :cascade do |t|
    t.datetime "created_at", null: false
    t.string "email_address", null: false
    t.string "password_digest", null: false
    t.datetime "updated_at", null: false
    t.index ["email_address"], name: "index_users_on_email_address", unique: true
  end

  add_foreign_key "leg_players", "legs"
  add_foreign_key "leg_players", "players"
  add_foreign_key "legs", "matches"
  add_foreign_key "players", "matches"
  add_foreign_key "players", "users"
  add_foreign_key "sessions", "users"
  add_foreign_key "throws", "turns"
  add_foreign_key "turns", "legs"
  add_foreign_key "turns", "players"
end
