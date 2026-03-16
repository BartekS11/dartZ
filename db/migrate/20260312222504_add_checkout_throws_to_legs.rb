class AddCheckoutThrowsToLegs < ActiveRecord::Migration[8.1]
  def change
    add_column :legs, :checkout_throws, :integer
  end
end
