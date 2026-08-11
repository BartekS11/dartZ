require "test_helper"

class ThrowsInviteTurnLockTest < ActionDispatch::IntegrationTest
  setup do
    @match = Match.create!(
      best_of_legs: 1,
      best_of_sets: 1,
      guest_token: SecureRandom.hex(24),
      invite_token: SecureRandom.urlsafe_base64(24),
      invite_created_at: 1.hour.ago,
      invite_expires_at: 23.hours.from_now,
      invite_joined_at: Time.current
    )
    @player1 = @match.players.create!(name: "Alice")
    @player2 = @match.players.create!(name: "Bob")
    @match.start_first_set!
    @turn = @match.current_leg.current_turn
  end

  test "invite opponent cannot submit before afk timeout" do
    assert_equal @player1, @turn.player

    post turn_throws_path(@turn),
         params: { guest_token: @match.guest_token, actor_player_id: @player2.id, throw: { total: 0 } },
         headers: { "Accept" => "text/vnd.turbo-stream.html" }

    assert_response :conflict
    @match.reload
    assert_equal @turn.id, @match.current_leg.current_turn.id
    assert_equal 501, @match.score_for(@player1)
  end

  test "invite opponent can skip stale turn as zero after afk timeout" do
    @turn.update!(updated_at: 3.minutes.ago)

    post turn_throws_path(@turn),
         params: { guest_token: @match.guest_token, actor_player_id: @player2.id, throw: { total: 0 } },
         headers: { "Accept" => "text/vnd.turbo-stream.html" }

    assert_response :success
    @match.reload
    assert_equal @player2, @match.current_leg.current_turn.player
    assert_equal 501, @match.score_for(@player1)
    assert_equal 0, Turn.find(@turn.id).total_score
  end

  test "invite opponent cannot click through throw pad before afk timeout" do
    post turn_throws_path(@turn),
         params: { guest_token: @match.guest_token, actor_player_id: @player2.id, throw: { segment: 20, multiplier: "triple" } },
         headers: { "Accept" => "text/vnd.turbo-stream.html" }

    assert_response :conflict
    @match.reload
    assert_equal @turn.id, @match.current_leg.current_turn.id
    assert_equal 501, @match.score_for(@player1)
    assert_equal 0, @turn.throws.count
  end

  test "invite current player can submit from throw pad" do
    post turn_throws_path(@turn),
         params: { guest_token: @match.guest_token, actor_player_id: @player1.id, throw: { segment: 20, multiplier: "triple" } },
         headers: { "Accept" => "text/vnd.turbo-stream.html" }

    assert_response :success
    @match.reload
    assert_equal 441, @match.score_for(@player1)
    assert_equal 1, @turn.reload.throws.count
  end
end
