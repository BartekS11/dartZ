class BotTurnJob < ApplicationJob
  queue_as :default

  def perform(turn_id)
    turn  = Turn.find_by(id: turn_id)
    return unless turn
    return if turn.completed?

    match  = turn.leg.match
    player = turn.player
    return unless player.bot?

    score = match.score_for(player)
    level = player.bot_level || 10
    leg_player = turn.leg.leg_players.find_by!(player: player)

    Rails.logger.info "BOT TURN: score=#{score} level=#{level}"
    sleep bot_initial_delay

    throws = BotService.play_turn(
      score: score,
      level: level,
      double_in: match.double_in?,
      double_out: match.double_out?,
      has_doubled_in: leg_player.has_doubled_in?
    )["throws"] || []

    throws.each_with_index do |throw_name, i|
      turn.reload
      break if turn.completed?

      attrs = BotService.throw_to_attributes(throw_name)
      Rails.logger.info "BOT THROW: #{throw_name} → #{attrs.inspect}"

      match.with_lock do
        turn.reload
        next if turn.completed?

        throw_record = turn.throws.create!(segment: attrs[:segment], multiplier: attrs[:multiplier])
        turn.apply_throw!(throw_record, broadcast: true)
      end

      sleep bot_throw_delay unless i == throws.size - 1
    end
  rescue ActiveRecord::RecordNotFound
    # Turn or match was deleted — ignore
  end

  private

  def bot_initial_delay
    ENV.fetch("BOT_TURN_INITIAL_DELAY", Rails.env.test? ? "0" : "0.4").to_f
  end

  def bot_throw_delay
    ENV.fetch("BOT_TURN_THROW_DELAY", Rails.env.test? ? "0" : "0.25").to_f
  end
end
