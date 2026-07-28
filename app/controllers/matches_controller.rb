class MatchesController < ApplicationController
  allow_unauthenticated_access
  before_action :resume_session_optional, only: %i[index show create summary checkout clear]
  rescue_from ActiveRecord::RecordNotFound, with: :match_not_found

  def index
    if Current.user
      @matches = Match
        .joins(:players)
        .where(players: { user_id: Current.user.id })
        .includes(players: :user, match_sets: [ { legs: [ { turns: :throws }, { leg_players: :player } ] } ])
        .distinct
        .order(created_at: :desc)
        .limit(10)
    else
      @matches = Match.none
    end
  end

  def show
    @match = Match.includes(players: :user, match_sets: [ { legs: [ { turns: :throws }, { leg_players: :player } ] } ]).find(params[:id])
    authorize_match!(@match)
    return if performed?

    remember_guest_match!(@match)
    if @match.invite_pending?
      redirect_to match_invite_path(@match)
      return
    end

    @current_match_player = current_match_player(@match)
    @presenter = MatchStatePresenter.new(@match)
    @players = @presenter.players
    return if @presenter.finished?

    @turn = @presenter.current_turn
  end

  def create
    if params[:invite_match].present?
      create_invite_match
      return
    end

    p1_name = params[:player1_name].to_s.strip.presence || Current.user&.display_name || "Player 1"
    p2_name = params[:player2_name].to_s.strip.presence || "Player 2"

    @match = MatchCreator.call(
      settings: MatchSettings.from_params(params),
      players: [
        { name: p1_name, user: Current.user, dart_setup: current_dart_setup_snapshot },
        { name: p2_name }
      ],
      guest_match: Current.user.nil?,
      nickname_user: Current.user,
      nickname: p1_name
    )

    remember_guest_match!(@match, @match.guest_token) unless Current.user
    redirect_to match_path(@match)
  end

  def summary
    match = Match.includes(players: :user, match_sets: [ { legs: [ { turns: :throws }, { leg_players: :player } ] } ]).find(params[:id])
    authorize_match!(match)
    return if performed?

    render json: MatchStatePresenter.new(match).summary_payload
  end

  def checkout
    match  = Match.find(params[:id])
    authorize_match!(match)
    return if performed?

    player = match.players.find(params[:player_id])
    score  = match.score_for(player)

    suggestion = match.double_out? ? CheckoutCalculator.suggest(score) : []

    render json: {
      score:      score,
      suggestion: suggestion,
      possible:   suggestion.present?
    }
  end

  def clear
    return head :unauthorized unless Current.user

    matches = Match
      .joins(:players)
      .where(players: { user_id: Current.user.id })
      .distinct

    matches.find_each(&:destroy!)

    head :no_content
  end

  private

  def create_invite_match
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

  def current_dart_setup_snapshot
    Current.user&.premium_access? ? Current.user.dart_setup : nil
  end

  def match_not_found
    redirect_to matches_path, alert: "Match not found"
  end
end
