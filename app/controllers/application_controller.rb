class ApplicationController < ActionController::Base
  include Authentication

  MAX_GUEST_MATCH_TOKENS = 20
  # Only allow modern browsers supporting webp images, web push, badges, import maps, CSS nesting, and CSS :has.
  allow_browser versions: :modern

  # Changes to the importmap will invalidate the etag for HTML responses
  stale_when_importmap_changes

  helper_method :premium_access?

  private

  def premium_access?
    Current.user&.premium_access?
  end

  def require_premium_access
    return if premium_access?

    redirect_to matches_path, alert: "Premium access is required for that feature."
  end

  def authorize_match!(match)
    return if MatchAccess.new(match: match, user: Current.user, guest_token: guest_token_for(match)).allowed?

    respond_to do |format|
      format.turbo_stream { head :forbidden }
      format.json { render json: { error: "Forbidden" }, status: :forbidden }
      format.html { redirect_to matches_path, alert: "You don't have access to that match." }
    end
  end

  def remember_match_player!(match, player)
    return if match.blank? || player.blank?

    player_ids = cookies.signed[:match_player_ids] || {}
    player_ids = player_ids.to_h.merge(match.id.to_s => player.id).to_a.last(MAX_GUEST_MATCH_TOKENS).to_h
    cookies.signed.permanent[:match_player_ids] = { value: player_ids, httponly: true, same_site: :lax }
  end

  def current_match_player(match)
    return nil if match.blank?

    if params[:player_id].present?
      param_player = match.players.find_by(id: params[:player_id])
      if param_player
        remember_match_player!(match, param_player)
        return param_player
      end
    end

    if Current.user
      user_player = match.players.find_by(user_id: Current.user.id)
      return user_player if user_player
    end

    player_id = (cookies.signed[:match_player_ids] || {})[match.id.to_s]
    match.players.find_by(id: player_id) if player_id.present?
  end

  def remember_guest_match!(match, token = params[:guest_token])
    return if token.blank? || match.guest_token.blank?
    return if Current.user && TournamentMatch.find_by(linked_match: match).blank?
    return unless MatchAccess.new(match: match, guest_token: token).allowed?

    tokens = cookies.signed[:guest_match_tokens] || {}
    tokens = tokens.to_h.merge(match.id.to_s => token).to_a.last(MAX_GUEST_MATCH_TOKENS).to_h
    cookies.signed.permanent[:guest_match_tokens] = { value: tokens, httponly: true, same_site: :lax }
  end

  def guest_token_for(match)
    params[:guest_token].presence || (cookies.signed[:guest_match_tokens] || {})[match.id.to_s]
  end
end
