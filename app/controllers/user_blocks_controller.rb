class UserBlocksController < ApplicationController
  before_action -> { require_roadmap_feature!(:friends) }

  def create
    target = User.find_by_public_id!(params[:user_id])
    Social::FriendshipManager.block(actor: Current.user, target: target)
    redirect_to friends_path, notice: t("friends.flashes.user_blocked")
  rescue ActiveRecord::RecordNotFound, Social::Error
    redirect_to friends_path, alert: t("friends.flashes.unavailable")
  end

  def destroy
    block = UserBlock.find_by_public_id!(params[:id])
    Social::FriendshipManager.unblock(actor: Current.user, block: block)
    redirect_to friends_path, notice: t("friends.flashes.user_unblocked")
  rescue ActiveRecord::RecordNotFound, Social::Error
    redirect_to friends_path, alert: t("friends.flashes.unavailable")
  end
end
