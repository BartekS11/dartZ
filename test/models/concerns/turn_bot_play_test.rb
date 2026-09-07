require "test_helper"

class TurnBotPlayTest < ActiveSupport::TestCase
  setup do
    @match = Match.create!
    @bot = @match.players.create!(name: "Bot", bot: true, bot_level: 8)
    @human = @match.players.create!(name: "Human")
    @match.start_first_set!
    @turn = @match.current_leg.current_turn
    @turn.stubs(:sleep)
    @turn.stubs(:broadcast_turn_change!)
  end

  test "plays generated throws using match rules and advances to human" do
    BotService.expects(:play_turn).with(
      score: 501, level: 8, double_in: false, double_out: true, has_doubled_in: true
    ).returns("throws" => [ "T20", "S20", "D20" ])

    @turn.play_bot_now

    assert_equal [ 60, 20, 40 ], @turn.throws.order(:created_at).map(&:points)
    assert @turn.reload.completed?
    assert_equal 381, @match.score_for(@bot)
    assert_equal @human, @match.current_leg.current_turn.player
  end

  test "does not generate throws for a human or completed turn" do
    BotService.expects(:play_turn).never
    @turn.update!(completed_at: Time.current)
    @turn.play_bot_now
    @turn.update!(completed_at: nil, player: @human)
    @turn.play_bot_now

    assert_empty @turn.throws
  end

  test "stops after a checkout even when the bot supplies more throws" do
    @turn.leg.leg_players.find_by!(player: @bot).update!(score: 40)
    BotService.stubs(:play_turn).returns("throws" => [ "D20", "S20", "S20" ])

    @turn.play_bot_now

    assert_equal 1, @turn.throws.count
    assert @turn.reload.completed?
    assert @match.reload.finished?
  end

  test "rechecks completion inside the match lock" do
    BotService.stubs(:play_turn).returns("throws" => [ "S20" ])
    @turn.leg.stubs(:match).returns(@match)
    @match.expects(:with_lock).yields
    @turn.expects(:completed?).times(3).returns(false, false, true)

    @turn.play_bot_now

    assert_empty @turn.throws
  end

  test "an absent throw list is a no-op" do
    BotService.stubs(:play_turn).returns({})

    @turn.play_bot_now

    assert_empty @turn.throws
    refute @turn.reload.completed?
  end
end
