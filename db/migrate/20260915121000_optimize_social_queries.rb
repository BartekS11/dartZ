class OptimizeSocialQueries < ActiveRecord::Migration[8.1]
  def change
    add_index :users, "LOWER(nickname)",
      name: "index_discoverable_users_on_lower_nickname",
      where: "discoverable_by_nickname = TRUE"
    add_index :friend_requests, %i[requester_id status created_at],
      name: "index_friend_requests_outgoing_status_created"
    add_index :match_challenges, %i[challenger_id status created_at],
      name: "index_match_challenges_outgoing_status_created"
    add_index :user_blocks, %i[blocker_id created_at],
      name: "index_user_blocks_on_blocker_created"
  end
end
