require "test_helper"

class BotTurnJobTest < ActiveJob::TestCase
  test "delegates gameplay to the turn" do
    turn = mock("turn")
    Turn.expects(:find_by).with(id: 123).returns(turn)
    turn.expects(:play_bot_now)

    BotTurnJob.perform_now(123)
  end

  test "ignores a deleted turn" do
    Turn.expects(:find_by).with(id: 123).returns(nil)

    assert_nothing_raised { BotTurnJob.perform_now(123) }
  end

  test "ignores records deleted during play" do
    turn = mock("turn")
    Turn.expects(:find_by).with(id: 123).returns(turn)
    turn.expects(:play_bot_now).raises(ActiveRecord::RecordNotFound)

    assert_nothing_raised { BotTurnJob.perform_now(123) }
  end
end
