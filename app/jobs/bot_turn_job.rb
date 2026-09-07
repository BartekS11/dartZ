class BotTurnJob < ApplicationJob
  queue_as :default

  def perform(turn_id)
    Turn.find_by(id: turn_id)&.play_bot_now
  rescue ActiveRecord::RecordNotFound
    # Turn or match was deleted — ignore
  end
end
