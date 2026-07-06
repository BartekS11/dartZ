module TournamentAccessControl
  extend ActiveSupport::Concern

  private

  def authorize_tournament_admin!(tournament = @tournament)
    return true if tournament.can_administer?(user: Current.user, admin_token: params[:admin_token])

    redirect_to tournament_path(tournament), alert: "Unauthorized"
    false
  end

  def tournament_admin_path(tournament = @tournament)
    tournament_path(tournament, admin_token: params[:admin_token])
  end
end
