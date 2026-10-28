require "test_helper"

class BotUndoTest < ActiveSupport::TestCase
  setup do
    @match = Match.create!
    @human = @match.players.create!(name: "Human")
    @bot = @match.players.create!(name: "Bot", bot: true, bot_level: 5)
    @match.start_first_set!
    @human_turn = @match.current_leg.current_turn
  end

  test "undo while the bot is queued returns to the human and cancels the queued reply" do
    submit_human_total
    reply = @match.current_leg.current_turn

    assert @match.undo_last_throw!(mode: "total")
    assert_rewound(reply)
    assert_no_difference("Throw.count") { BotTurnJob.perform_now(reply.id) }
  end

  test "undo during a partial bot reply restores both scores" do
    submit_human_total
    reply = @match.current_leg.current_turn
    dart = reply.throws.create!(segment: 20, multiplier: "single")
    reply.apply_throw!(dart, broadcast: false)
    assert_equal 481, @match.score_for(@bot)

    assert @match.undo_last_throw!(mode: "total")
    assert_rewound(reply)
  end

  test "undo after a complete bot reply removes the reply and empty next human turn" do
    submit_human_total
    reply = @match.current_leg.current_turn
    BotService.stubs(:play_turn).returns("throws" => ["S20", "S20", "S20"])
    reply.stubs(:sleep)
    reply.play_bot_now
    next_turn = @match.current_leg.current_turn
    assert_equal @human, next_turn.player

    assert @match.undo_last_throw!(mode: "total")
    assert_rewound(reply)
    refute Turn.exists?(next_turn.id)
  end

  test "single undo removes only the last human dart and discards the bot reply" do
    3.times { ThrowSubmission.call(turn: @human_turn, throw_attributes: { segment: 20, multiplier: "single" }) }
    reply = @match.current_leg.current_turn

    assert @match.undo_last_throw!(mode: "single")
    assert_equal @human_turn.id, @match.current_leg.current_turn.id
    assert_equal 461, @match.score_for(@human)
    assert_equal 2, @human_turn.reload.throws.count
    refute @human_turn.completed?
    refute Turn.exists?(reply.id)
  end

  test "a running bot job stops when undo deletes its turn between darts" do
    submit_human_total
    reply = @match.current_leg.current_turn
    match = @match
    BotService.stubs(:play_turn).returns("throws" => ["S20", "S20", "S20"])
    reply.define_singleton_method(:sleep) do |_delay|
      match.undo_last_throw!(mode: "total") if throws.exists?
    end

    reply.play_bot_now

    assert_rewound(reply)
  end

  test "undo restores double-in state after removing a bot opening double" do
    @match.update!(double_in: true)
    @match.current_leg.leg_players.update_all(has_doubled_in: false)
    ThrowSubmission.call(turn: @human_turn, throw_attributes: { segment: 20, multiplier: "double" })
    @human_turn.complete_turn!(broadcast: false)
    reply = @match.current_leg.current_turn
    dart = reply.throws.create!(segment: 20, multiplier: "double")
    reply.apply_throw!(dart, broadcast: false)

    assert @match.undo_last_throw!(mode: "total")
    assert_equal 501, @match.score_for(@human)
    assert_equal 501, @match.score_for(@bot)
    @match.current_leg.leg_players.each { |lp| refute lp.has_doubled_in? }
  end

  test "bot busts are not refunded as scored points" do
    submit_human_total
    reply = @match.current_leg.current_turn
    # Use a short starting score so the first bot dart busts.
    @match.current_leg.leg_players.find_by!(player: @bot).update!(starting_score: 21, score: 21)
    dart = reply.throws.create!(segment: 20, multiplier: "triple")
    reply.apply_throw!(dart, broadcast: false)

    assert @match.undo_last_throw!(mode: "total")
    assert_equal 21, @match.score_for(@bot)
  end

  test "undo preserves scores and darts from earlier rounds" do
    submit_human_total
    first_reply = @match.current_leg.current_turn
    BotService.stubs(:play_turn).returns("throws" => ["S20", "S20", "S20"])
    first_reply.stubs(:sleep)
    first_reply.play_bot_now
    second_human = @match.current_leg.current_turn
    ThrowSubmission.call(turn: second_human, total: 100)
    second_reply = @match.current_leg.current_turn
    dart = second_reply.throws.create!(segment: 20, multiplier: "single")
    second_reply.apply_throw!(dart, broadcast: false)

    assert @match.undo_last_throw!(mode: "total")
    assert_equal second_human.id, @match.current_leg.current_turn.id
    assert_equal 441, @match.score_for(@human)
    assert_equal 441, @match.score_for(@bot)
    assert_equal 3, first_reply.reload.throws.count
    assert_equal 60, @human_turn.reload.total_score
  end

  test "undoing a human bust does not add unscored points" do
    lp = @match.current_leg.leg_players.find_by!(player: @human)
    lp.update!(starting_score: 21, score: 21)
    ThrowSubmission.call(turn: @human_turn, throw_attributes: { segment: 20, multiplier: "triple" })

    assert @match.undo_last_throw!(mode: "total")
    assert_equal 21, @match.score_for(@human)
    assert_empty @human_turn.reload.throws
  end

  test "undo has no effect when only the bot has played" do
    @human_turn.update!(player: @bot)
    dart = @human_turn.throws.create!(segment: 20, multiplier: "single")
    @human_turn.apply_throw!(dart, broadcast: false)

    refute @match.undo_last_throw!(mode: "total")
    assert_equal 481, @match.score_for(@bot)
    assert_equal 1, @human_turn.reload.throws.count
  end

  private

  def submit_human_total
    ThrowSubmission.call(turn: @human_turn, total: 60)
  end

  def assert_rewound(reply)
    assert_equal @human_turn.id, @match.reload.current_leg.current_turn.id
    assert_equal 501, @match.score_for(@human)
    assert_equal 501, @match.score_for(@bot)
    assert_empty @human_turn.reload.throws
    assert_nil @human_turn.total_score
    refute @human_turn.completed?
    refute Turn.exists?(reply.id)
  end
end
