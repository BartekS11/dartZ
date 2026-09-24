require "test_helper"

class Social::FriendshipManagerTest < ActiveSupport::TestCase
  setup do
    @alice = create_user("alice-social-#{SecureRandom.hex(4)}@example.com")
    @bob = create_user("bob-social-#{SecureRandom.hex(4)}@example.com")
    @alice.update!(nickname: "Alice")
    @bob.update!(nickname: "Bob")
  end

  test "share-code request can be accepted and is idempotent in one direction" do
    request_record = Social::FriendshipManager.send_request(
      actor: @alice,
      target: @bob,
      share_code: @bob.friend_share_code
    )
    duplicate = Social::FriendshipManager.send_request(
      actor: @alice,
      target: @bob,
      share_code: @bob.friend_share_code
    )

    assert_equal request_record, duplicate
    friendship = Social::FriendshipManager.accept(actor: @bob, request: request_record)
    assert_equal [ @alice.id, @bob.id ].sort, [ friendship.user_low_id, friendship.user_high_id ]
    assert_equal "accepted", request_record.reload.status
  end

  test "privacy and blocks return generic unavailable errors" do
    assert_raises(Social::Error) do
      Social::FriendshipManager.send_request(actor: @alice, target: @bob, share_code: "WRONGCODE000")
    end

    @bob.update!(friend_request_policy: "anyone")
    Social::FriendshipManager.block(actor: @bob, target: @alice)
    error = assert_raises(Social::Error) do
      Social::FriendshipManager.send_request(actor: @alice, target: @bob)
    end
    assert_equal "not_found", error.code
  end

  test "reciprocal pending request must be accepted rather than duplicated" do
    @bob.update!(friend_request_policy: "anyone")
    request_record = Social::FriendshipManager.send_request(actor: @alice, target: @bob)

    error = assert_raises(Social::Error) do
      Social::FriendshipManager.send_request(actor: @bob, target: @alice, share_code: @alice.friend_share_code)
    end
    assert_equal "conflict", error.code
    assert_equal 1, FriendRequest.pending.where(pair_key: request_record.pair_key).count
  end

  test "blocking removes friendship and pending social activity without disclosing reverse block" do
    friendship = Friendship.create_between!(@alice, @bob)
    challenge = Social::ChallengeManager.create(
      actor: @alice,
      target: @bob,
      settings: MatchSettings.from_params({ starting_score: 501, best_of_legs: 3, best_of_sets: 1 })
    )

    block = Social::FriendshipManager.block(actor: @bob, target: @alice)

    assert_not Friendship.exists?(friendship.id)
    assert_equal "cancelled", challenge.reload.status
    assert challenge.match.reload.invite_cancelled_at?
    assert_equal @alice, block.blocked
    assert_not_includes @alice.blocks_created, block
  end
end
