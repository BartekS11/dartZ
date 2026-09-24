class FriendshipsController < ApplicationController
  before_action -> { require_roadmap_feature!(:friends) }

  def destroy
    friendship = Friendship.find_by_public_id!(params[:id])
    Social::FriendshipManager.remove(actor: Current.user, friendship: friendship)
    redirect_to friends_path, notice: t("friends.flashes.friend_removed")
  rescue ActiveRecord::RecordNotFound, Social::Error
    redirect_to friends_path, alert: t("friends.flashes.unavailable")
  end
end
