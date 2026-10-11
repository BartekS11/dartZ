class AddStripeCancelAtPeriodEndToUsers < ActiveRecord::Migration[8.1]
  def change
    add_column :users, :stripe_cancel_at_period_end, :boolean, default: false, null: false
  end
end
