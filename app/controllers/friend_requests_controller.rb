class FriendRequestsController < ApplicationController
  before_action -> { require_roadmap_feature!(:friends) }
  rate_limit to: 20, within: 1.hour, only: :create, by: -> { Current.user&.id || request.remote_ip },
    with: -> { redirect_to friends_path, alert: t("friends.flashes.rate_limited") }

  def create
    target = User.find_by_public_id!(params[:recipient_id])
    Social::FriendshipManager.send_request(actor: Current.user, target: target, share_code: params[:share_code])
    redirect_to friends_path, notice: t("friends.flashes.request_sent")
  rescue ActiveRecord::RecordNotFound, Social::Error => error
    social_redirect(error)
  end

  def accept
    Social::FriendshipManager.accept(actor: Current.user, request: find_request)
    redirect_to friends_path, notice: t("friends.flashes.request_accepted")
  rescue ActiveRecord::RecordNotFound, Social::Error => error
    social_redirect(error)
  end

  def decline
    Social::FriendshipManager.decline(actor: Current.user, request: find_request)
    redirect_to friends_path, notice: t("friends.flashes.request_declined")
  rescue ActiveRecord::RecordNotFound, Social::Error => error
    social_redirect(error)
  end

  def destroy
    Social::FriendshipManager.cancel(actor: Current.user, request: find_request)
    redirect_to friends_path, notice: t("friends.flashes.request_cancelled")
  rescue ActiveRecord::RecordNotFound, Social::Error => error
    social_redirect(error)
  end

  private

  def find_request
    FriendRequest.find_by_public_id!(params[:id])
  end

  def social_redirect(_error)
    redirect_to friends_path, alert: t("friends.flashes.unavailable")
  end
end
