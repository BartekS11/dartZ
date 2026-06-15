class TournamentMatchesController < ApplicationController
  allow_unauthenticated_access only: %i[launch report]
  before_action :resume_session_optional
  before_action :set_tournament
  before_action :set_tournament_match

  def launch
    unless @tournament.can_administer?(user: Current.user, admin_token: params[:admin_token])
      redirect_to tournament_path(@tournament), alert: "Unauthorized"
      return
    end

    if @tournament_match.linked_match.present?
      redirect_to match_path(@tournament_match.linked_match)
      return
    end

    match = Match.create!(best_of_legs: @tournament_match.best_of_legs, best_of_sets: @tournament_match.best_of_sets)
    match.players.create!(name: @tournament_match.home_entry.name)
    match.players.create!(name: @tournament_match.away_entry.name)
    match.start_first_set!
    match.ensure_match_identifier!

    @tournament_match.update!(linked_match: match, status: "live")
    @tournament.broadcast_live_update!
    redirect_to match_path(match)
  end

  def report
    unless @tournament.can_administer?(user: Current.user, admin_token: params[:admin_token])
      redirect_to tournament_path(@tournament), alert: "Unauthorized"
      return
    end

    home_sets = params[:home_sets].to_i
    away_sets = params[:away_sets].to_i
    home_legs = params[:home_legs].to_i
    away_legs = params[:away_legs].to_i
    winner = home_sets > away_sets || (home_sets == away_sets && home_legs > away_legs) ? @tournament_match.home_entry : @tournament_match.away_entry

    @tournament_match.update!(home_sets:, away_sets:, home_legs:, away_legs:, winner_entry: winner, status: "complete", completed_at: Time.current)
    TournamentProgressor.new(@tournament).call
    @tournament.broadcast_live_update!

    redirect_to tournament_path(@tournament, admin_token: params[:admin_token]), notice: "Result saved."
  end

  private

  def set_tournament
    @tournament = Tournament.find(params[:tournament_id])
  end

  def set_tournament_match
    @tournament_match = @tournament.tournament_matches.find(params[:id])
  end
end
