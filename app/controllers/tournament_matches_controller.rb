class TournamentMatchesController < ApplicationController
  include TournamentAccessControl

  allow_unauthenticated_access only: %i[launch report]
  before_action :resume_session_optional
  before_action :set_tournament
  before_action :set_tournament_match

  def launch
    return unless authorize_tournament_admin!

    if @tournament_match.linked_match.present?
      @tournament_match.linked_match.ensure_guest_token!
      remember_guest_match!(@tournament_match.linked_match, @tournament_match.linked_match.guest_token)
      redirect_to match_path(@tournament_match.linked_match, guest_token: @tournament_match.linked_match.guest_token)
      return
    end

    match = nil
    @tournament.with_lock do
      ApplicationRecord.transaction do
        @tournament_match.reload
        match = MatchCreator.call(
          settings: MatchSettings.from_tournament_match(@tournament_match),
          players: [
            { name: @tournament_match.home_entry.name },
            { name: @tournament_match.away_entry.name }
          ],
          guest_match: true
        )

        @tournament_match.update!(linked_match: match, status: "live")
      end
    end
    @tournament.broadcast_live_update!
    remember_guest_match!(match, match.guest_token)
    redirect_to match_path(match, guest_token: match.guest_token)
  end

  def report
    return unless authorize_tournament_admin!

    home_sets = params[:home_sets].to_i
    away_sets = params[:away_sets].to_i
    home_legs = params[:home_legs].to_i
    away_legs = params[:away_legs].to_i
    winner = home_sets > away_sets || (home_sets == away_sets && home_legs > away_legs) ? @tournament_match.home_entry : @tournament_match.away_entry

    @tournament.with_lock do
      @tournament_match.update!(home_sets:, away_sets:, home_legs:, away_legs:, winner_entry: winner, status: "complete", completed_at: Time.current)
      TournamentProgressor.new(@tournament).call
    end
    @tournament.broadcast_live_update!

    redirect_to tournament_admin_path, notice: t("flashes.result_saved")
  end

  private

  def set_tournament
    @tournament = Tournament.find(params[:tournament_id])
  end

  def set_tournament_match
    @tournament_match = @tournament.tournament_matches.find(params[:id])
  end
end
