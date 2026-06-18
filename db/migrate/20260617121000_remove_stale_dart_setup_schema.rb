class RemoveStaleDartSetupSchema < ActiveRecord::Migration[8.1]
  def up
    remove_column :players, :dart_setup_id if column_exists?(:players, :dart_setup_id)
    drop_table :dart_setups, if_exists: true
  end

  def down
    add_column :players, :dart_setup_id, :integer unless column_exists?(:players, :dart_setup_id)

    return if table_exists?(:dart_setups)

    create_table :dart_setups do |t|
      t.integer :dart_model_id, null: false
      t.string :name
      t.text :notes
      t.integer :player_id, null: false
      t.integer :point_length_mm
      t.integer :shaft_length_mm
      t.string :shaft_type
      t.decimal :weight_g, precision: 4, scale: 1
      t.timestamps
    end

    add_index :dart_setups, :player_id
  end
end
