class AddPlayoffRoundFormatSettingsToTournaments < ActiveRecord::Migration[8.1]
  def change
    add_column :tournaments, :semifinal_best_of_legs, :integer
    add_column :tournaments, :final_best_of_legs, :integer
  end
end
