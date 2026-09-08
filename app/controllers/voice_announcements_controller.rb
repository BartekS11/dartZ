class VoiceAnnouncementsController < ApplicationController
  allow_unauthenticated_access
  before_action :resume_session_optional

  def show
    path = VoiceAnnouncement.path_for(params[:id])
    return head :not_found unless VoiceAnnouncement.authorized_user?(Current.user) && path&.file?

    expires_now
    response.headers["Cache-Control"] = "private, no-store"
    send_file path, type: "audio/mpeg", disposition: "inline"
  end
end
