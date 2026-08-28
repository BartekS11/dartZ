class TournamentEntriesController < ApplicationController
  allow_unauthenticated_access
  before_action :resume_session_optional
  before_action :set_tournament
  before_action :set_entry, only: %i[update destroy]

  def create
    unless @tournament.join_token == params[:join_token]
      redirect_to tournament_path(@tournament), alert: t("flashes.invalid_join_link")
      return
    end

    name = params[:name].to_s.strip
    next_seed = @tournament.entries.maximum(:seed).to_i + 1
    group_count = @tournament.effective_group_count(entries_count: next_seed)
    group_name = @tournament.group_stage_enabled? ? TournamentGroupNaming.label((next_seed - 1) % group_count) : nil
    entry = @tournament.entries.build(name:, seed: next_seed, group_name: group_name)
    entry.user = Current.user if Current.user

    if entry.save
      @tournament.broadcast_live_update!
      redirect_to tournament_path(@tournament, participant_token: entry.access_token), notice: t("flashes.tournament_joined")
    else
      redirect_to tournament_path(@tournament), alert: entry.errors.full_messages.to_sentence
    end
  end

  def update
    unless @tournament.can_administer?(user: Current.user, admin_token: params[:admin_token])
      redirect_to tournament_path(@tournament), alert: t("flashes.unauthorized")
      return
    end

    if @entry.update(entry_params)
      @tournament.broadcast_live_update!
      redirect_to tournament_path(@tournament, admin_token: params[:admin_token]), notice: t("flashes.player_updated")
    else
      redirect_to tournament_path(@tournament, admin_token: params[:admin_token]), alert: @entry.errors.full_messages.to_sentence
    end
  end

  def destroy
    unless @tournament.can_administer?(user: Current.user, admin_token: params[:admin_token])
      redirect_to tournament_path(@tournament), alert: t("flashes.unauthorized")
      return
    end

    @entry.destroy!
    TournamentGenerator.new(@tournament).call if @tournament.status == "active" && @tournament.entries.size >= 2
    @tournament.broadcast_live_update!
    redirect_to tournament_path(@tournament, admin_token: params[:admin_token]), notice: t("flashes.player_removed")
  end

  private

  def set_tournament
    @tournament = Tournament.find(params[:tournament_id])
  end

  def set_entry
    @entry = @tournament.entries.find(params[:id])
  end

  def entry_params
    params.require(:tournament_entry).permit(:name, :seed, :group_name)
  end
end
