class AddStripeSubscriptionStateToUsers < ActiveRecord::Migration[8.1]
  def change
    add_column :users, :stripe_subscription_status, :string
    add_column :users, :stripe_price_id, :string
    add_column :users, :subscription_currency, :string
  end
end
