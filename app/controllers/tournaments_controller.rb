class TournamentsController < ApplicationController
  allow_unauthenticated_access
  before_action :resume_session_optional
  before_action :set_tournament, only: %i[show update destroy regenerate advance_round reseed]

  def index
    @guest_tournaments = Tournament.guest_public.order(created_at: :desc).limit(30)
    @my_tournaments = Current.user ? Tournament.owned_by(Current.user).order(created_at: :desc) : Tournament.none
  end

  def new
    @tournament = Tournament.new(
      format_type: "groups",
      best_of_legs: 1,
      best_of_sets: 1,
      seeding_mode: "auto",
      playoff_mode: "single_elimination",
      auto_advance: true,
      manual_advance_allowed: true,
      bronze_match: false
    )
  end

  def create
    @tournament = Tournament.new(tournament_params)
    @tournament.owner_user = Current.user if Current.user
    @tournament.visibility = Current.user ? "participant_only" : "public_guest"

    entry_names = extract_entry_names
    build_entries(@tournament, entry_names)

    if @tournament.save
      TournamentGenerator.new(@tournament).call if @tournament.entries.size >= 2
      redirect_to tournament_path(@tournament, admin_token: (@tournament.guest_owned? ? @tournament.admin_token : nil)), notice: "Tournament created."
    else
      render :new, status: :unprocessable_entity
    end
  end

  def show
    @tournament.sync_from_linked_matches!
    unless @tournament.can_view?(user: Current.user, admin_token: params[:admin_token], participant_token: params[:participant_token], join_token: params[:join_token])
      redirect_to tournaments_path, alert: "You don't have access to that tournament."
      return
    end

    @can_admin = @tournament.can_administer?(user: Current.user, admin_token: params[:admin_token])
    @participant_token = params[:participant_token]
  end

  def update
    unless @tournament.can_administer?(user: Current.user, admin_token: params[:admin_token])
      redirect_to tournament_path(@tournament), alert: "Unauthorized"
      return
    end

    if @tournament.update(tournament_params)
      TournamentGenerator.new(@tournament).call if @tournament.entries.size >= 2
      @tournament.broadcast_live_update!
      redirect_to tournament_path(@tournament, admin_token: params[:admin_token]), notice: "Tournament updated."
    else
      redirect_to tournament_path(@tournament, admin_token: params[:admin_token]), alert: @tournament.errors.full_messages.to_sentence
    end
  end

  def destroy
    unless @tournament.can_administer?(user: Current.user, admin_token: params[:admin_token])
      redirect_to tournament_path(@tournament), alert: "Unauthorized"
      return
    end

    @tournament.destroy!
    redirect_to tournaments_path, notice: "Tournament deleted."
  end

  def regenerate
    unless @tournament.can_administer?(user: Current.user, admin_token: params[:admin_token])
      redirect_to tournament_path(@tournament), alert: "Unauthorized"
      return
    end

    TournamentGenerator.new(@tournament).call
    @tournament.broadcast_live_update!
    redirect_to tournament_path(@tournament, admin_token: params[:admin_token]), notice: "Tournament regenerated."
  end

  def reseed
    unless @tournament.can_administer?(user: Current.user, admin_token: params[:admin_token])
      redirect_to tournament_path(@tournament), alert: "Unauthorized"
      return
    end

    @tournament.entries.order(:created_at).each_with_index do |entry, idx|
      entry.update!(seed: idx + 1)
    end
    TournamentGenerator.new(@tournament).call if @tournament.entries.size >= 2
    @tournament.broadcast_live_update!
    redirect_to tournament_path(@tournament, admin_token: params[:admin_token]), notice: "Seeds rebuilt."
  end

  def advance_round
    unless @tournament.can_administer?(user: Current.user, admin_token: params[:admin_token])
      redirect_to tournament_path(@tournament), alert: "Unauthorized"
      return
    end

    case @tournament.format_type
    when "swiss"
      if SwissRoundGenerator.new(@tournament).call
        TournamentProgressor.new(@tournament).call
        @tournament.broadcast_live_update!
        redirect_to tournament_path(@tournament, admin_token: params[:admin_token]), notice: "Next swiss round created."
      else
        redirect_to tournament_path(@tournament, admin_token: params[:admin_token]), alert: "Unable to generate the next swiss round yet."
      end
    when "playoffs"
      previous_round_count = @tournament.rounds.count
      PlayoffProgressor.new(@tournament).call
      TournamentProgressor.new(@tournament).call
      @tournament.broadcast_live_update!

      if @tournament.rounds.count > previous_round_count || @tournament.status == "complete"
        redirect_to tournament_path(@tournament, admin_token: params[:admin_token]), notice: "Playoff bracket advanced."
      else
        redirect_to tournament_path(@tournament, admin_token: params[:admin_token]), alert: "Unable to advance the playoff bracket yet."
      end
    else
      redirect_to tournament_path(@tournament, admin_token: params[:admin_token]), alert: "Manual round advance is not available for this format."
    end
  end

  private

  def set_tournament
    @tournament = Tournament.find(params[:id])
  end

  def tournament_params
    params.require(:tournament).permit(:title, :format_type, :best_of_legs, :best_of_sets, :seeding_mode, :playoff_mode, :bronze_match, :auto_advance, :manual_advance_allowed, :group_count, :swiss_round_count, :playoff_qualifier_count, :allow_wildcards)
  end

  def extract_entry_names
    params[:tournament][:entry_names].to_s.lines.map(&:strip).reject(&:blank?).uniq
  end

  def build_entries(tournament, names)
    names.each_with_index do |name, idx|
      tournament.entries.build(name:, seed: idx + 1)
    end
  end
end
