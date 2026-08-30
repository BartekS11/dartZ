class BotMatchesController < ApplicationController
  before_action :require_authentication

  def new
  end

  def create
    human_name = params[:player_name].to_s.strip.presence || Current.user.display_name
    bot_level  = BotService.normalize_level(params[:bot_level].presence || BotService::DEFAULT_LEVEL)
    bot_name   = params[:bot_name].to_s.strip.presence || "Bot (Level #{bot_level})"

    @match = MatchCreator.call(
      settings: MatchSettings.from_params(params),
      players: [
        { name: human_name, user: Current.user },
        { name: bot_name, bot: true, bot_level: bot_level }
      ],
      nickname_user: Current.user,
      nickname: human_name
    )

    # If bot goes first, enqueue immediately
    first_turn = @match.current_leg&.current_turn
    if first_turn&.player&.bot?
      BotTurnJob.perform_later(first_turn.id)
    end

    redirect_to match_path(@match)
  end
end
