class MatchPlayerOrdersController < ApplicationController
  allow_unauthenticated_access
  before_action :resume_session_optional

  def update
    match = Match.find_by_public_id!(params[:match_id])
    authorize_match!(match)
    return if performed?

    remember_guest_match!(match)

    if !match.player_thrower_swap_context?
      redirect_to match_path(match), alert: t("flashes.player_order_unavailable"), status: :see_other
    elsif match.invite_match? && !match.invite_host?(Current.user)
      redirect_to match_path(match), alert: t("flashes.player_order_host_only"), status: :see_other
    elsif !match.player_thrower_swappable?
      redirect_to match_path(match), alert: t("flashes.player_order_unavailable"), status: :see_other
    elsif match.swap_current_thrower
      broadcast_player_order(match)
      redirect_to match_path(match), notice: t("flashes.player_order_swapped"), status: :see_other
    else
      redirect_to match_path(match), alert: t("flashes.player_order_unavailable"), status: :see_other
    end
  end

  private
    def broadcast_player_order(match)
      presenter = MatchStatePresenter.new(match.reload)

      Turbo::StreamsChannel.broadcast_replace_to(
        "match_#{match.id}",
        target: "score-cards-section",
        partial: "matches/score_cards",
        locals: { match: match, presenter: presenter }
      )
      Turbo::StreamsChannel.broadcast_update_to(
        "match_#{match.id}",
        target: "current-player",
        partial: "matches/current_player",
        locals: {
          match: match,
          presenter: presenter,
          turn: presenter.current_turn,
          show_player_order_control: false
        }
      )
    end
end
