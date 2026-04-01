class AddBotToPlayers < ActiveRecord::Migration[8.0]
  def change
    add_column :players, :bot,       :boolean, default: false, null: false
    add_column :players, :bot_level, :integer, default: 10
  end
end