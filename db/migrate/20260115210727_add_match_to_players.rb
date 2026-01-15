class AddMatchToPlayers < ActiveRecord::Migration[8.1]
  def change
    add_reference :players, :match, null: true, foreign_key: true
  end
end
