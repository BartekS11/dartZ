require "test_helper"

class TurnFlowTest < ActiveJob::TestCase
  setup do
    @original_adapter = ActiveJob::Base.queue_adapter
    ActiveJob::Base.queue_adapter = :test
  end

  teardown do
    ActiveJob::Base.queue_adapter = @original_adapter
    clear_enqueued_jobs
    clear_performed_jobs
  end

  test "complete_turn! marks turn completed" do
    _match, leg, turn = create_turn_context

    assert_nil turn.completed_at

    turn.complete_turn!(broadcast: false)

    assert_not_nil turn.reload.completed_at
  end

  test "complete_turn! does nothing when already completed" do
    _match, leg, turn = create_turn_context
    turn.update!(completed_at: 1.minute.ago)

    assert_no_difference("Turn.count") do
      turn.complete_turn!(broadcast: false)
    end

    assert_in_delta 1.minute.ago.to_i, turn.reload.completed_at.to_i, 2
  end

  test "complete_turn! starts next turn when leg is not finished" do
    _match, leg, turn = create_turn_context

    assert_difference("Turn.count", 1) do
      turn.complete_turn!(broadcast: false)
    end

    assert_equal leg.turns.order(:created_at).last, leg.current_turn
    refute_equal turn.id, leg.current_turn.id
  end

  test "complete_turn! enqueues bot job when next turn belongs to bot" do
    match = Match.create!
    human = match.players.create!(name: "Human")
    bot   = match.players.create!(name: "Bot", bot: true, bot_level: 10)
    set   = match.match_sets.create!
    leg   = set.legs.create!(match: match)
    leg.start_first_turn!
    turn = leg.current_turn

    assert_enqueued_with(job: BotTurnJob) do
      turn.complete_turn!(broadcast: false)
    end

    assert_equal bot, leg.current_turn.player
  end

  test "complete_turn! does not start a new turn for finished leg" do
    _match, leg, turn = create_turn_context
    leg.update!(finished_at: Time.current)

    assert_no_difference("Turn.count") do
      turn.complete_turn!(broadcast: false)
    end
  end

  private

  def create_turn_context
    match = Match.create!
    match.players.create!(name: "Player 1")
    match.players.create!(name: "Player 2")
    set = match.match_sets.create!
    leg = set.legs.create!(match: match)
    leg.start_first_turn!
    [ match, leg, leg.current_turn ]
  end
end
