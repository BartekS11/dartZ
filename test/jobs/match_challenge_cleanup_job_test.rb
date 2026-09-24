require "test_helper"

class MatchChallengeCleanupJobTest < ActiveJob::TestCase
  include ActiveSupport::Testing::TimeHelpers

  test "expires only overdue pending challenges and cancels their invitations" do
    alice = create_user("cleanup-alice-#{SecureRandom.hex(4)}@example.com")
    bob = create_user("cleanup-bob-#{SecureRandom.hex(4)}@example.com")
    Friendship.create_between!(alice, bob)
    settings = MatchSettings.from_params({ starting_score: 501, best_of_legs: 1, best_of_sets: 1 })
    stale = Social::ChallengeManager.create(actor: alice, target: bob, settings: settings)
    now = Time.current

    travel_to now + 23.hours
    fresh = Social::ChallengeManager.create(actor: alice, target: create_friend(alice), settings: settings)
    travel_to now + 25.hours

    MatchChallengeCleanupJob.perform_now

    assert_equal "expired", stale.reload.status
    assert_equal "pending", fresh.reload.status
  end

  private

  def create_friend(user)
    friend = create_user("cleanup-friend-#{SecureRandom.hex(4)}@example.com")
    Friendship.create_between!(user, friend)
    friend
  end
end
