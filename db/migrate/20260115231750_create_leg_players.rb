class CreateLegPlayers < ActiveRecord::Migration[8.1]
  def change
    create_table :leg_players do |t|
      t.references :leg, null: false, foreign_key: true
      t.references :player, null: false, foreign_key: true
      t.integer :starting_score

      t.timestamps
    end
  end
end
