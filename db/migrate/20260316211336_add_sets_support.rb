class AddSetsSupport < ActiveRecord::Migration[8.0]
  def change
    # Match configuration
    add_column :matches, :best_of_legs, :integer, default: 1, null: false
    add_column :matches, :best_of_sets, :integer, default: 1, null: false

    # Sets table
    create_table :sets do |t|
      t.references :match, null: false, foreign_key: true
      t.integer    :winner_id
      t.datetime   :finished_at
      t.timestamps
    end

    # Leg belongs to set
    add_reference :legs, :set, foreign_key: true
  end
end