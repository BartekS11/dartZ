class AddLiveBoardSettingsToTournaments < ActiveRecord::Migration[8.1]
  def change
    add_column :tournaments, :playoff_best_of_legs, :integer
    add_column :tournaments, :playoff_best_of_sets, :integer
    add_column :tournaments, :playoff_starting_score, :integer
    add_column :tournaments, :playoff_double_in, :boolean
    add_column :tournaments, :playoff_double_out, :boolean
    add_column :tournaments, :qualifiers_per_group, :integer
  end
end
