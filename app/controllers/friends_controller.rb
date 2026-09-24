class FriendsController < ApplicationController
  PER_PAGE = 25
  SEARCH_LIMIT = 25

  before_action -> { require_roadmap_feature!(:friends) }
  before_action :load_social_data, only: %i[show search]
  rate_limit to: 30, within: 1.hour, only: :search, by: -> { Current.user&.id || request.remote_ip },
    with: -> { redirect_to friends_path, alert: t("friends.flashes.rate_limited") }

  def show; end

  def search
    @search_results = Social::UserDiscovery.call(viewer: Current.user, query: params[:q]).limit(SEARCH_LIMIT)
    render :show
  end

  def update
    Current.user.update!(privacy_params)
    redirect_to friends_path, notice: t("friends.flashes.privacy_updated")
  rescue ActiveRecord::RecordInvalid
    redirect_to friends_path, alert: t("friends.flashes.invalid_settings")
  end

  private

  def load_social_data
    @social_pagination = {}
    @friendships = paginate_social(
      Friendship.for_user(Current.user).includes(:user_low, :user_high).order(created_at: :desc, public_id: :desc),
      :friendships_page
    )
    @incoming_requests = paginate_social(
      Current.user.received_friend_requests.pending.includes(:requester).order(created_at: :desc, public_id: :desc),
      :incoming_page
    )
    @outgoing_requests = paginate_social(
      Current.user.sent_friend_requests.pending.includes(:recipient).order(created_at: :desc, public_id: :desc),
      :outgoing_page
    )
    @blocks = paginate_social(
      Current.user.blocks_created.includes(:blocked).order(created_at: :desc, public_id: :desc),
      :blocks_page
    )
    @challenges = paginate_social(
      MatchChallenge.for_user(Current.user).includes(:challenger, :challenged, :match)
        .order(created_at: :desc, public_id: :desc),
      :challenges_page
    )
  end

  def paginate_social(scope, parameter)
    page = [ params.fetch(parameter, 1).to_i, 1 ].max
    records = scope.limit(PER_PAGE + 1).offset((page - 1) * PER_PAGE).to_a
    @social_pagination[parameter] = { parameter: parameter, page: page, next: records.length > PER_PAGE }
    records.first(PER_PAGE)
  end

  def privacy_params
    params.require(:user).permit(:discoverable_by_nickname, :friend_request_policy, :challenge_policy)
  end
end
