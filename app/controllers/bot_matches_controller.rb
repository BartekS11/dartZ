class BotMatchesController < ApplicationController
  before_action :require_authentication

  def new
  end

  def create
    @match = Match.new(
      best_of_legs: params[:best_of_legs].to_i.clamp(1, 99),
      best_of_sets: params[:best_of_sets].to_i.clamp(1, 99),
      starting_score: permitted_starting_score,
      double_in: truthy_param?(:double_in),
      double_out: truthy_param?(:double_out, default: true)
    )

    human_name = params[:player_name].to_s.strip.presence || Current.user.display_name
    bot_level  = params[:bot_level].to_i.clamp(1, 20)
    bot_name   = params[:bot_name].to_s.strip.presence || "Bot (Level #{bot_level})"

    ApplicationRecord.transaction do
      @match.save!
      Current.user.update!(nickname: human_name) if Current.user.nickname != human_name

      @match.players.create!(name: human_name, user: Current.user)
      @match.players.create!(name: bot_name, bot: true, bot_level: bot_level)

      @match.ensure_match_identifier!
      @match.start_first_set!
    end

    # If bot goes first, enqueue immediately
    first_turn = @match.current_leg&.current_turn
    if first_turn&.player&.bot?
      BotTurnJob.perform_later(first_turn.id)
    end

    redirect_to match_path(@match)
  end

  private

  def permitted_starting_score
    score = params[:starting_score].to_i
    Match::X01_STARTING_SCORES.include?(score) ? score : 501
  end

  def truthy_param?(key, default: false)
    return default unless params.key?(key)

    ActiveModel::Type::Boolean.new.cast(params[key])
  end
end
