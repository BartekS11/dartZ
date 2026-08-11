class MatchInvitesController < ApplicationController
  allow_unauthenticated_access
  rescue_from ActiveRecord::RecordNotFound, with: :invite_not_found
  before_action :resume_session_optional
  before_action :set_match_by_id, only: %i[show status cancel]
  before_action :authorize_waiting_match!, only: %i[show status cancel]
  before_action :set_match_by_token, only: %i[join create]

  def show
    if @match.invite_cancelled?
      render :cancelled, status: :gone
    elsif @match.invite_expired?
      render :expired, status: :gone
    elsif @match.invite_full?
      redirect_to match_path(@match)
    end
  end

  def status
    joined = @match.invite_joined_at.present?
    player = current_match_player(@match) if joined

    render json: {
      joined: joined,
      match_url: joined ? match_path(@match, player_id: player&.id) : nil
    }
  end

  def new
    create_invite
  end

  def create_invite
    unless Current.user
      redirect_to matches_path, alert: t("flashes.invite_sign_in")
      return
    end

    p1_name = params[:player1_name].to_s.strip.presence || Current.user&.display_name || "Player 1"

    @match = Match.new(MatchSettings.from_params(params).to_h)

    ApplicationRecord.transaction do
      @match.ensure_guest_token! if Current.user.nil?
      @match.ensure_invite_token!
      @match.save!

      if Current.user && Current.user.nickname != p1_name
        Current.user.update!(nickname: p1_name)
      end

      player = @match.players.build(name: p1_name, user: Current.user)
      player.assign_dart_setup_snapshot!(current_dart_setup_snapshot) if current_dart_setup_snapshot
      player.save!
      remember_match_player!(@match, player)
      @match.ensure_match_identifier!
    end

    remember_guest_match!(@match, @match.guest_token) unless Current.user
    redirect_to match_invite_path(@match)
  end

  def join
    if @match.invite_cancelled?
      render :cancelled, status: :gone
    elsif @match.invite_expired?
      render :expired, status: :gone
    elsif @match.invite_full?
      render :full, status: :conflict
    end
  end

  def create
    @match.with_lock do
      @match.reload
      if @match.invite_cancelled?
        redirect_to match_invite_join_path(@match.invite_token), alert: t("flashes.invite_cancelled") and return
      elsif @match.invite_expired?
        redirect_to match_invite_join_path(@match.invite_token), alert: t("flashes.invite_expired") and return
      elsif @match.invite_full?
        redirect_to match_invite_join_path(@match.invite_token), alert: t("flashes.invite_full") and return
      end

      p2_name = params[:player_name].to_s.strip.presence || Current.user&.display_name || "Player 2"
      player = @match.players.build(name: p2_name, user: Current.user)
      player.assign_dart_setup_snapshot!(current_dart_setup_snapshot) if current_dart_setup_snapshot
      player.save!
      remember_match_player!(@match, player)
      @match.ensure_guest_token! if Current.user.nil?
      @match.update!(invite_joined_at: Time.current)
      @match.start_first_set! if @match.match_sets.none?
    end

    remember_guest_match!(@match, @match.guest_token) unless Current.user
    joined_player = @match.players.order(:created_at).last
    redirect_to match_path(@match, player_id: joined_player.id)
  end

  def cancel
    @match.cancel_invite! if @match.invite_pending?
    redirect_to matches_path, notice: t("flashes.invite_cancelled_notice")
  end

  private

  def set_match_by_id
    @match = Match.find(params[:id])
  end

  def set_match_by_token
    @match = Match.find_by!(invite_token: params[:token])
  end

  def authorize_waiting_match!
    authorize_match!(@match)
  end

  def current_dart_setup_snapshot
    Current.user&.premium_access? ? Current.user.dart_setup : nil
  end

  def invite_not_found
    redirect_to matches_path, alert: t("flashes.invite_not_found")
  end
end
