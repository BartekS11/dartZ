class MatchChannel < ApplicationCable::Channel
  def subscribed
    match = Match.find(params[:match_id])
    stream_from "match_#{match.id}_api"
  rescue ActiveRecord::RecordNotFound
    reject
  end

  def unsubscribed
    stop_all_streams
  end
end
