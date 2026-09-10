class VoiceAnnouncementsController < ApplicationController
  allow_unauthenticated_access
  before_action :resume_session_optional

  def show
    path = case params[:id]
    when "no-score" then VoiceAnnouncement.path_for("no-score")
    when "26" then VoiceAnnouncement.path_for("26")
    when "41" then VoiceAnnouncement.path_for("41")
    when "45" then VoiceAnnouncement.path_for("45")
    when "100" then VoiceAnnouncement.path_for("100")
    when "180" then VoiceAnnouncement.path_for("180")
    end
    return head :not_found unless VoiceAnnouncement.authorized_user?(Current.user) && path&.file?

    send_file path, type: "audio/mpeg", disposition: "inline"
    response.headers["Cache-Control"] = "private, no-store"
  end
end
