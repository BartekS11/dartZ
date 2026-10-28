require "test_helper"

class ThrowsBotUndoTest < ActionDispatch::IntegrationTest
  [false, true].each do |completed|
    test "undo restores the human turn with completed bot reply=#{completed}" do
      match = Match.create!(guest_token: SecureRandom.hex(24))
      human = match.players.create!(name: "Human")
      bot = match.players.create!(name: "Bot", bot: true, bot_level: 5)
      match.start_first_set!
      human_turn = match.current_leg.current_turn
      ThrowSubmission.call(turn: human_turn, total: 60)
      reply = match.current_leg.current_turn
      BotService.stubs(:play_turn).returns("throws" => ["S20", "S20", "S20"])
      if completed
        reply.stubs(:sleep)
        reply.play_bot_now
      else
        dart = reply.throws.create!(segment: 20, multiplier: "single")
        reply.apply_throw!(dart, broadcast: false)
      end

      delete undo_turn_throw_path(match.current_leg.current_turn),
        params: { guest_token: match.guest_token },
        headers: { "Accept" => "text/vnd.turbo-stream.html", "X-Undo-Mode" => "total" }

      assert_response :success
      assert_equal human_turn.id, match.reload.current_leg.current_turn.id
      assert_equal 501, match.score_for(human)
      assert_equal 501, match.score_for(bot)
      assert_select "turbo-stream[target='current-player']" do
        assert_select "[data-keyboard-bot-turn-value='false']"
        assert_select "#match-score-input[disabled]", count: 0
      end
    end
  end
end
