class AddMatchIdentifierToMatches < ActiveRecord::Migration[8.1]
  def change
    add_column :matches, :match_identifier, :string
    add_index :matches, :match_identifier, unique: true
  end
end
