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

    result = BotService.play_turn(score: score, level: level)
    Rails.logger.info "BOT RESULT: #{result.inspect}"

    throws = result["throws"] || []
    Rails.logger.info "BOT THROWS: #{throws.inspect}"

    throws.each_with_index do |throw_name, i|
      turn.reload
      break if turn.completed?

      segment, multiplier = parse_throw_name(throw_name)
      Rails.logger.info "BOT THROW: #{throw_name} → segment=#{segment} multiplier=#{multiplier}"

      throw_record = turn.throws.create!(segment: segment, multiplier: multiplier)
      turn.apply_throw!(throw_record, broadcast: true)

      sleep 0.8 unless i == throws.size - 1
    end
  rescue ActiveRecord::RecordNotFound
    # Turn or match was deleted — ignore
  end

  private

  def parse_throw_name(name)
    return [ 0,  "miss" ]   if name == "MISS"
    return [ 25, "double" ] if name == "Bull"
    return [ 25, "single" ] if name == "25"

    prefix = name[0]
    num    = name[1..].to_i

    case prefix
    when "T" then [ num, "triple" ]
    when "D" then [ num, "double" ]
    when "S" then [ num, "single" ]
    else          [ 1,   "single" ]
    end
  end
end
