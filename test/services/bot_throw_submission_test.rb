require "test_helper"

class BotThrowSubmissionTest < ActiveSupport::TestCase
  test "manual total and single dart submissions cannot modify a bot turn" do
    match = Match.create!
    bot = match.players.create!(name: "Bot", bot: true, bot_level: 10)
    match.players.create!(name: "Human")
    match.start_first_set!
    turn = match.current_leg.current_turn

    [ { total: 60 }, { throw_attributes: { segment: 20, multiplier: "triple" } } ].each do |submission|
      assert_no_difference("Throw.count") do
        ThrowSubmission.call(turn: turn, **submission)
      end
      assert_equal 501, match.reload.score_for(bot)
      assert_nil turn.reload.total_score
      refute turn.completed?
    end
  end
end
