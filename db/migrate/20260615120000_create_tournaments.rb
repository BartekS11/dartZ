class CreateTournaments < ActiveRecord::Migration[8.1]
  def change
    create_table :tournaments do |t|
      t.string :title, null: false
      t.references :owner_user, foreign_key: { to_table: :users }
      t.string :format_type, null: false
      t.string :visibility, null: false, default: "public_guest"
      t.string :status, null: false, default: "draft"
      t.string :share_token, null: false
      t.string :admin_token, null: false
      t.string :join_token, null: false
      t.integer :best_of_legs, null: false, default: 1
      t.integer :best_of_sets, null: false, default: 1
      t.string :seeding_mode, null: false, default: "auto"
      t.string :playoff_mode, null: false, default: "single_elimination"
      t.boolean :bronze_match, null: false, default: false
      t.boolean :auto_advance, null: false, default: true
      t.boolean :manual_advance_allowed, null: false, default: true
      t.integer :group_count
      t.integer :swiss_round_count
      t.integer :playoff_qualifier_count
      t.boolean :allow_wildcards, null: false, default: false
      t.jsonb :settings, null: false, default: {}
      t.datetime :published_at
      t.timestamps
    end

    add_index :tournaments, :share_token, unique: true
    add_index :tournaments, :admin_token, unique: true
    add_index :tournaments, :join_token, unique: true

    create_table :tournament_entries do |t|
      t.references :tournament, null: false, foreign_key: true
      t.references :user, foreign_key: true
      t.string :name, null: false
      t.integer :seed
      t.string :status, null: false, default: "active"
      t.string :group_name
      t.string :access_token, null: false
      t.integer :wins, null: false, default: 0
      t.integer :losses, null: false, default: 0
      t.integer :draws, null: false, default: 0
      t.integer :legs_for, null: false, default: 0
      t.integer :legs_against, null: false, default: 0
      t.integer :points, null: false, default: 0
      t.decimal :buchholz, null: false, default: 0, precision: 8, scale: 2
      t.timestamps
    end

    add_index :tournament_entries, [:tournament_id, :name], unique: true
    add_index :tournament_entries, :access_token, unique: true

    create_table :tournament_rounds do |t|
      t.references :tournament, null: false, foreign_key: true
      t.integer :number, null: false
      t.string :name, null: false
      t.string :stage_type, null: false
      t.string :status, null: false, default: "pending"
      t.string :bracket
      t.string :group_name
      t.jsonb :settings, null: false, default: {}
      t.timestamps
    end

    add_index :tournament_rounds, [:tournament_id, :number, :bracket, :group_name], name: "idx_tournament_rounds_uniqueness"

    create_table :tournament_matches do |t|
      t.references :tournament, null: false, foreign_key: true
      t.references :tournament_round, null: false, foreign_key: true
      t.references :home_entry, foreign_key: { to_table: :tournament_entries }
      t.references :away_entry, foreign_key: { to_table: :tournament_entries }
      t.references :winner_entry, foreign_key: { to_table: :tournament_entries }
      t.references :linked_match, foreign_key: { to_table: :matches }
      t.string :status, null: false, default: "pending"
      t.string :source, null: false, default: "generated"
      t.string :bracket
      t.integer :position
      t.boolean :bye, null: false, default: false
      t.integer :best_of_legs, null: false, default: 1
      t.integer :best_of_sets, null: false, default: 1
      t.integer :home_legs, null: false, default: 0
      t.integer :away_legs, null: false, default: 0
      t.integer :home_sets, null: false, default: 0
      t.integer :away_sets, null: false, default: 0
      t.jsonb :settings, null: false, default: {}
      t.datetime :completed_at
      t.timestamps
    end

    add_index :tournament_matches, [:tournament_round_id, :position], unique: true
  end
end
