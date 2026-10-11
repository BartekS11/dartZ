class AddMatchReviewShares < ActiveRecord::Migration[8.1]
  def change
    add_column :matches, :review_share_token, :string
    add_index :matches, :review_share_token, unique: true, where: "review_share_token IS NOT NULL"
  end
end
