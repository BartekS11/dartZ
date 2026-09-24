class MatchChallengesController < ApplicationController
  before_action -> { require_roadmap_feature!(:friends) }
  rate_limit to: 20, within: 1.hour, only: :create, by: -> { Current.user&.id || request.remote_ip },
    with: -> { redirect_to friends_path, alert: t("friends.flashes.rate_limited") }

  def create
    target = User.find_by_public_id!(params[:user_id])
    Social::ChallengeManager.create(actor: Current.user, target: target, settings: MatchSettings.from_params(params))
    redirect_to friends_path, notice: t("friends.flashes.challenge_sent")
  rescue ActiveRecord::RecordNotFound, Social::Error
    redirect_to friends_path, alert: t("friends.flashes.unavailable")
  end

  def accept
    challenge, player = Social::ChallengeManager.accept(actor: Current.user, challenge: find_challenge)
    remember_match_player!(challenge.match, player)
    redirect_to match_path(challenge.match, player_id: player.public_id), notice: t("friends.flashes.challenge_accepted")
  rescue ActiveRecord::RecordNotFound, Social::Error
    redirect_to friends_path, alert: t("friends.flashes.unavailable")
  end

  def decline
    Social::ChallengeManager.decline(actor: Current.user, challenge: find_challenge)
    redirect_to friends_path, notice: t("friends.flashes.challenge_declined")
  rescue ActiveRecord::RecordNotFound, Social::Error
    redirect_to friends_path, alert: t("friends.flashes.unavailable")
  end

  def destroy
    Social::ChallengeManager.cancel(actor: Current.user, challenge: find_challenge)
    redirect_to friends_path, notice: t("friends.flashes.challenge_cancelled")
  rescue ActiveRecord::RecordNotFound, Social::Error
    redirect_to friends_path, alert: t("friends.flashes.unavailable")
  end

  private

  def find_challenge
    MatchChallenge.find_by_public_id!(params[:id])
  end
end
