class ApplicationController < ActionController::Base
  include Authentication
  # Only allow modern browsers supporting webp images, web push, badges, import maps, CSS nesting, and CSS :has.
  allow_browser versions: :modern

  # Changes to the importmap will invalidate the etag for HTML responses
  stale_when_importmap_changes

  private

  def authorize_match!(match)
    return if MatchAccess.new(match: match, user: Current.user, guest_token: guest_token_for(match)).allowed?

    respond_to do |format|
      format.turbo_stream { head :forbidden }
      format.json { render json: { error: "Forbidden" }, status: :forbidden }
      format.html { redirect_to matches_path, alert: "You don't have access to that match." }
    end
  end

  def remember_guest_match!(match, token = params[:guest_token])
    return if Current.user || token.blank? || match.guest_token.blank?
    return unless MatchAccess.new(match: match, guest_token: token).allowed?

    tokens = cookies.signed[:guest_match_tokens] || {}
    tokens = tokens.to_h.merge(match.id.to_s => token)
    cookies.signed.permanent[:guest_match_tokens] = { value: tokens, httponly: true, same_site: :lax }
  end

  def guest_token_for(match)
    params[:guest_token].presence || (cookies.signed[:guest_match_tokens] || {})[match.id.to_s]
  end
end
