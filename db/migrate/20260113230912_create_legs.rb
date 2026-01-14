class CreateLegs < ActiveRecord::Migration[8.1]
  def change
    create_table :legs do |t|
      t.references :match, null: false, foreign_key: true
      t.integer :starting_score
      t.datetime :finished_at

      t.timestamps
    end
  end
end
