module TurnBotPlay
  extend ActiveSupport::Concern

  def play_bot_now
    return if completed?
    return unless player.bot?

    match = leg.match
    score = match.score_for(player)
    level = player.bot_level || 10
    current_leg_player = leg.leg_players.find_by!(player: player)

    Rails.logger.info "BOT TURN: score=#{score} level=#{level}"
    sleep bot_initial_delay

    throws = BotService.play_turn(
      score: score,
      level: level,
      double_in: match.double_in?,
      double_out: match.double_out?,
      has_doubled_in: current_leg_player.has_doubled_in?
    )["throws"] || []

    throws.each_with_index do |throw_name, index|
      reload
      break if completed?

      attrs = BotService.throw_to_attributes(throw_name)
      Rails.logger.info "BOT THROW: #{throw_name} → #{attrs.inspect}"

      match.with_lock do
        reload
        next if completed?

        throw_record = self.throws.create!(segment: attrs[:segment], multiplier: attrs[:multiplier])
        apply_throw!(throw_record, broadcast: true)
      end

      sleep bot_throw_delay unless index == throws.size - 1
    end
  end

  private
    def bot_initial_delay
      ENV.fetch("BOT_TURN_INITIAL_DELAY", Rails.env.test? ? "0" : "0.4").to_f
    end

    def bot_throw_delay
      ENV.fetch("BOT_TURN_THROW_DELAY", Rails.env.test? ? "0" : "0.25").to_f
    end
end
