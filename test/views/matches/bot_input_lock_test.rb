require "test_helper"

class BotInputLockTest < ActionView::TestCase
  [ true, false ].each do |bot_turn|
    test "score entry lock for bot=#{bot_turn}" do
      match = Match.create!
      match.players.create!(name: "Starter", bot: bot_turn)
      match.players.create!(name: "Other")
      match.start_first_set!
      view.stubs(:current_match_player).returns(nil)

      render partial: "matches/current_player", locals: {
        match: match, presenter: MatchStatePresenter.new(match),
        turn: match.current_leg.current_turn
      }

      assert_select "[data-keyboard-bot-turn-value='#{bot_turn}']", count: 1
      assert_select "#match-score-input[disabled]", count: bot_turn ? 1 : 0
      assert_select ".match-score-submit[disabled]", count: bot_turn ? 1 : 0
      assert_select ".match-input-panel.bot-turn-disabled", count: bot_turn ? 1 : 0
    end
  end
end
