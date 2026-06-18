class MatchChannel < ApplicationCable::Channel
  def subscribed
    match = Match.find(params[:match_id])
    unless MatchAccess.new(match: match, user: current_user, guest_id: guest_id, guest_token: params[:guest_token]).allowed?
      reject
      return
    end

    stream_from "match_#{match.id}_api"
  rescue ActiveRecord::RecordNotFound
    reject
  end

  def unsubscribed
    stop_all_streams
  end
end
