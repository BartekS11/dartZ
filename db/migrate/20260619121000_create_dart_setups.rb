class CreateDartSetups < ActiveRecord::Migration[8.1]
  def change
    create_table :dart_setups do |t|
      t.references :user, null: false, foreign_key: true, index: { unique: true }
      t.decimal :weight_g, precision: 4, scale: 1, null: false
      t.string :shaft_type, null: false
      t.integer :shaft_length_mm, null: false
      t.integer :point_length_mm, null: false

      t.timestamps
    end
  end
end
