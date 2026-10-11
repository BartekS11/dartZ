class MatchSharesController < ApplicationController
  allow_unauthenticated_access

  def show
    match = Match.includes(players: :user, match_sets: [ { legs: [ { turns: :throws }, { leg_players: :player } ] } ])
      .find_by!(review_share_token: params[:token])
    return head :not_found unless match.finished? && match.review_shared?

    response.headers["Cache-Control"] = "no-store, private"
    response.headers["X-Robots-Tag"] = "noindex, nofollow, noarchive"
    @result = MatchShareSerializer.new(match: match).as_json
  end
end
