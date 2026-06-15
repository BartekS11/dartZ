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

    Rails.logger.info "BOT TURN: score=#{score} level=#{level}"
    sleep 1.5

    throws = BotService.play_turn(score: score, level: level)["throws"] || []

    throws.each_with_index do |throw_name, i|
      turn.reload
      break if turn.completed?

      attrs = BotService.throw_to_attributes(throw_name)
      Rails.logger.info "BOT THROW: #{throw_name} → #{attrs.inspect}"

      throw_record = turn.throws.create!(segment: attrs[:segment], multiplier: attrs[:multiplier])
      turn.apply_throw!(throw_record, broadcast: true)

      sleep 0.8 unless i == throws.size - 1
    end
  rescue ActiveRecord::RecordNotFound
    # Turn or match was deleted — ignore
  end
end
