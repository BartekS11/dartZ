class TournamentsController < ApplicationController
  include TournamentAccessControl

  allow_unauthenticated_access
  before_action :resume_session_optional
  before_action :set_tournament, only: %i[show live update destroy regenerate advance_round reseed]

  def index
    @guest_tournaments = Tournament.guest_public.order(created_at: :desc).limit(30)
    @my_tournaments = Current.user ? Tournament.owned_by(Current.user).order(created_at: :desc) : Tournament.none
  end

  def new
    @entry_names = ""
    @tournament = Tournament.new(
      format_type: "groups_playoffs",
      best_of_legs: 1,
      best_of_sets: 1,
      playoff_best_of_legs: 1,
      playoff_best_of_sets: 1,
      semifinal_best_of_legs: 3,
      final_best_of_legs: 5,
      starting_score: 501,
      playoff_starting_score: 501,
      double_in: false,
      double_out: true,
      playoff_double_in: false,
      playoff_double_out: true,
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
    @entry_names = params[:tournament][:entry_names].to_s
    build_entries(@tournament, entry_names)

    if @tournament.valid?
      ApplicationRecord.transaction do
        @tournament.save!
        TournamentGenerator.new(@tournament).call if @tournament.entries.size >= 2
      end
      redirect_to tournament_path(@tournament, admin_token: (@tournament.guest_owned? ? @tournament.admin_token : nil)), notice: "Tournament created."
    else
      render :new, status: :unprocessable_entity
    end
  end

  def show
    @tournament.sync_from_linked_matches!
    unless @tournament.can_view?(user: Current.user, admin_token: params[:admin_token], participant_token: params[:participant_token], join_token: params[:join_token], share_token: params[:share_token])
      redirect_to tournaments_path, alert: "You don't have access to that tournament."
      return
    end

    @can_admin = @tournament.can_administer?(user: Current.user, admin_token: params[:admin_token])
    @participant_token = params[:participant_token]
  end

  def live
    @tournament.sync_from_linked_matches!
    unless @tournament.can_view?(user: Current.user, admin_token: params[:admin_token], participant_token: params[:participant_token], join_token: params[:join_token], share_token: params[:share_token])
      redirect_to tournaments_path, alert: "You don't have access to that tournament."
      return
    end

    @can_admin = @tournament.can_administer?(user: Current.user, admin_token: params[:admin_token])
  end

  def update
    return unless authorize_tournament_admin!

    if @tournament.update(tournament_params)
      @tournament.with_lock do
        TournamentGenerator.new(@tournament).call if @tournament.entries.size >= 2
      end
      @tournament.broadcast_live_update!
      redirect_to tournament_admin_path, notice: "Tournament updated."
    else
      redirect_to tournament_admin_path, alert: @tournament.errors.full_messages.to_sentence
    end
  end

  def destroy
    return unless authorize_tournament_admin!

    @tournament.destroy!
    redirect_to tournaments_path, notice: "Tournament deleted."
  end

  def regenerate
    return unless authorize_tournament_admin!

    @tournament.with_lock do
      TournamentGenerator.new(@tournament).call
    end
    @tournament.broadcast_live_update!
    redirect_to tournament_admin_path, notice: "Tournament regenerated."
  end

  def reseed
    return unless authorize_tournament_admin!

    @tournament.with_lock do
      @tournament.entries.order(:created_at).each_with_index do |entry, idx|
        entry.update!(seed: idx + 1)
      end
      TournamentGenerator.new(@tournament).call if @tournament.entries.size >= 2
    end
    @tournament.broadcast_live_update!
    redirect_to tournament_admin_path, notice: "Seeds rebuilt."
  end

  def advance_round
    return unless authorize_tournament_admin!

    case @tournament.format_type
    when "swiss"
      generated = @tournament.with_lock do
        if SwissRoundGenerator.new(@tournament).call
          TournamentProgressor.new(@tournament).call
          true
        else
          false
        end
      end

      if generated
        @tournament.broadcast_live_update!
        redirect_to tournament_admin_path, notice: "Next swiss round created."
      else
        redirect_to tournament_admin_path, alert: "Unable to generate the next swiss round yet."
      end
    when "playoffs"
      previous_round_count = @tournament.rounds.count
      @tournament.with_lock do
        PlayoffProgressor.new(@tournament).call
        TournamentProgressor.new(@tournament).call
      end
      @tournament.broadcast_live_update!

      if @tournament.rounds.count > previous_round_count || @tournament.reload.status == "complete"
        redirect_to tournament_admin_path, notice: "Playoff bracket advanced."
      else
        redirect_to tournament_admin_path, alert: "Unable to advance the playoff bracket yet."
      end
    else
      redirect_to tournament_admin_path, alert: "Manual round advance is not available for this format."
    end
  end

  private

  def set_tournament
    @tournament = Tournament.find(params[:id])
  end

  def tournament_params
    params.require(:tournament).permit(:title, :format_type, :best_of_legs, :best_of_sets, :starting_score, :double_in, :double_out, :playoff_best_of_legs, :playoff_best_of_sets, :semifinal_best_of_legs, :final_best_of_legs, :playoff_starting_score, :playoff_double_in, :playoff_double_out, :qualifiers_per_group, :seeding_mode, :playoff_mode, :bronze_match, :auto_advance, :manual_advance_allowed, :group_count, :swiss_round_count, :playoff_qualifier_count, :allow_wildcards)
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
