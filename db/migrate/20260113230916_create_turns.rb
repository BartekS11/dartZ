class CreateTurns < ActiveRecord::Migration[8.1]
  def change
    create_table :turns do |t|
      t.references :leg, null: false, foreign_key: true
      t.integer :starting_score

      t.timestamps
    end
  end
end
