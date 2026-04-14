class BotService
  require "net/http"
  require "json"
  BASE_URL = "http://172.17.0.2:8080"

  def self.play_turn(score:, level:)
    uri      = URI("#{BASE_URL}/bot?score=#{score}&level=#{level}")
    response = Net::HTTP.get_response(uri)
    JSON.parse(response.body)
  rescue => e
    Rails.logger.error "BotService error: #{e.message}"
    { "throws" => [ "S1", "S1", "S1" ], "remaining" => score - 3 }
  end
end
