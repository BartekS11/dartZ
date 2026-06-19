class AddDartSetupTrackingToPlayers < ActiveRecord::Migration[8.1]
  def change
    add_reference :players, :dart_setup, foreign_key: true
    add_column :players, :dart_setup_snapshot, :jsonb, null: false, default: {}
    add_column :players, :dart_setup_fingerprint, :string

    add_index :players, [ :user_id, :dart_setup_fingerprint ]
  end
end
