class CreateThrows < ActiveRecord::Migration[8.1]
  def change
    create_table :throws do |t|
      t.references :turn, null: false, foreign_key: true
      t.integer :segment
      t.integer :multiplier

      t.timestamps
    end
  end
end
