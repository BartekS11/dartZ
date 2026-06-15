class MatchesController < ApplicationController
  allow_unauthenticated_access
  before_action :resume_session_optional, only: %i[index show create checkout clear]
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
    @presenter = MatchStatePresenter.new(@match)
    @players = @presenter.players
    return if @presenter.finished?

    @turn = @presenter.current_turn
  end

  def create
    @match = Match.new(
      best_of_legs: params[:best_of_legs].to_i.clamp(1, 99),
      best_of_sets: params[:best_of_sets].to_i.clamp(1, 99)
    )

    p1_name = params[:player1_name].to_s.strip.presence || Current.user&.display_name || "Player 1"
    p2_name = params[:player2_name].to_s.strip.presence || "Player 2"

    @match.save!

    Current.user&.update!(nickname: p1_name) if Current.user && Current.user.nickname != p1_name

    player1 = @match.players.create!(name: p1_name, user: Current.user)
    player2 = @match.players.create!(name: p2_name)

    @match.ensure_match_identifier!
    @match.start_first_set!

    redirect_to match_path(@match)
  end

  def summary
    match = Match.includes(players: :user, match_sets: [ { legs: [ { turns: :throws }, { leg_players: :player } ] } ]).find(params[:id])
    render json: MatchStatePresenter.new(match).summary_payload
  end

  def checkout
    match  = Match.find(params[:id])
    player = match.players.find(params[:player_id])
    score  = match.score_for(player)

    suggestion = CheckoutCalculator.suggest(score)

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

  def match_not_found
    redirect_to matches_path, alert: "Match not found"
  end
end
