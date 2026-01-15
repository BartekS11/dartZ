class RemovePlayerReferenceFromMatches < ActiveRecord::Migration[8.1]
def change
    if foreign_key_exists?(:matches, :players)
      remove_foreign_key :matches, :players
    end

    if column_exists?(:matches, :player_id)
      remove_column :matches, :player_id
    end
  end
end
