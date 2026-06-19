class AddManufacturerToDartSetups < ActiveRecord::Migration[8.1]
  def change
    add_column :dart_setups, :manufacturer, :string, null: false, default: "winmau"
  end
end
