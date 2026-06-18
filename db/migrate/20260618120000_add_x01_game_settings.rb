class AddX01GameSettings < ActiveRecord::Migration[8.1]
  def change
    add_column :matches, :starting_score, :integer, null: false, default: 501
    add_column :matches, :double_in, :boolean, null: false, default: false
    add_column :matches, :double_out, :boolean, null: false, default: true

    add_column :tournaments, :starting_score, :integer, null: false, default: 501
    add_column :tournaments, :double_in, :boolean, null: false, default: false
    add_column :tournaments, :double_out, :boolean, null: false, default: true

    add_column :tournament_matches, :starting_score, :integer, null: false, default: 501
    add_column :tournament_matches, :double_in, :boolean, null: false, default: false
    add_column :tournament_matches, :double_out, :boolean, null: false, default: true

    add_column :leg_players, :has_doubled_in, :boolean, null: false, default: false
  end
end
