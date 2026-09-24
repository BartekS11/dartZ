# frozen_string_literal: true

require "e2e_helper"

class FriendsAndChallengesFlowTest < E2EIntegrationTest
  setup do
    FeatureAccess.stubs(:enabled?).with(:friends).returns(true)
  end

  test "two free users become friends and enter a challenged X01 match" do
    alice = create_user(unique_email("friends-alice"))
    bob = create_user(unique_email("friends-bob"))
    alice.update!(nickname: "Alice")
    bob.update!(nickname: "Bob", discoverable_by_nickname: true, friend_request_policy: "anyone")

    login_as(alice)
    get search_friends_path(q: "Bob")
    assert_response :success
    assert_not_includes response.body, bob.email_address
    post friend_requests_path, params: { recipient_id: bob.public_id }
    request_record = alice.sent_friend_requests.pending.first!

    delete session_path
    login_as(bob)
    post accept_friend_request_path(request_record)
    assert Friendship.between(alice, bob)

    delete session_path
    login_as(alice)
    post challenges_path, params: {
      user_id: bob.public_id,
      starting_score: 301,
      best_of_legs: 3,
      best_of_sets: 1,
      double_out: true
    }
    challenge = alice.sent_match_challenges.pending.first!

    delete session_path
    login_as(bob)
    post accept_challenge_path(challenge)
    assert_redirected_to match_path(challenge.match, player_id: challenge.match.players.find_by!(user: bob).public_id)
    assert_equal "accepted", challenge.reload.status
    assert_equal 2, challenge.match.players.count
    assert challenge.match.match_sets.exists?
  end

  test "a block conceals both users and clears pending state" do
    alice = create_user(unique_email("blocked-alice"))
    bob = create_user(unique_email("blocked-bob"))
    bob.update!(nickname: "Hidden Bob", discoverable_by_nickname: true, friend_request_policy: "anyone")

    login_as(alice)
    post friend_requests_path, params: { recipient_id: bob.public_id }
    post blocks_path, params: { user_id: bob.public_id }

    assert_empty alice.sent_friend_requests.pending
    get search_friends_path(q: "Hidden Bob")
    assert_response :success
    assert_select "form[action='#{friend_requests_path}']", count: 0
  end
end
