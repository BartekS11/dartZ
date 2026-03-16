class RenameSetToMatchSet < ActiveRecord::Migration[8.1]
def change
  rename_table :sets, :match_sets
  rename_column :legs, :set_id, :match_set_id
end
end
