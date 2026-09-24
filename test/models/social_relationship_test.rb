require "test_helper"

class SocialRelationshipTest < ActiveSupport::TestCase
  setup do
    @one = create_user("social-model-one-#{SecureRandom.hex(4)}@example.com")
    @two = create_user("social-model-two-#{SecureRandom.hex(4)}@example.com")
  end

  test "users receive non-email public discovery identifiers and private defaults" do
    assert_match User.public_id_format, @one.public_id
    assert_match(/\A[A-Z0-9]{12}\z/, @one.friend_share_code)
    assert_equal "share_code_only", @one.friend_request_policy
    assert_equal "friends", @one.challenge_policy
    assert_not @one.discoverable_by_nickname?
  end

  test "friendship canonical order and uniqueness are enforced" do
    friendship = Friendship.create_between!(@two, @one)
    assert_operator friendship.user_low_id, :<, friendship.user_high_id
    assert_raises(ActiveRecord::RecordInvalid) { Friendship.create_between!(@one, @two) }
  end

  test "database allows only one pending request per unordered pair" do
    FriendRequest.create!(requester: @one, recipient: @two)
    reverse = FriendRequest.new(requester: @two, recipient: @one)

    assert_raises(ActiveRecord::RecordNotUnique) { reverse.save! }
  end

  test "database rejects self relationships and invalid states" do
    assert_raises(ActiveRecord::StatementInvalid) do
      ApplicationRecord.transaction(requires_new: true) do
        UserBlock.insert_all!([{ blocker_id: @one.id, blocked_id: @one.id, public_id: "bl_1234567890ABCDEF", created_at: Time.current, updated_at: Time.current }])
      end
    end
    assert_raises(ActiveRecord::StatementInvalid) do
      ApplicationRecord.transaction(requires_new: true) do
        FriendRequest.insert_all!([{
          requester_id: @one.id,
          recipient_id: @two.id,
          pair_key: [ @one.id, @two.id ].sort.join(":"),
          public_id: "fq_1234567890ABCDEF",
          status: "invalid",
          created_at: Time.current,
          updated_at: Time.current
        }])
      end
    end
  end
end
