require "test_helper"

class Social::ChallengeManagerTest < ActiveSupport::TestCase
  include ActiveSupport::Testing::TimeHelpers

  setup do
    @challenger = create_user("challenger-#{SecureRandom.hex(4)}@example.com")
    @challenged = create_user("challenged-#{SecureRandom.hex(4)}@example.com")
    @challenger.update!(nickname: "Host")
    @challenged.update!(nickname: "Guest")
    Friendship.create_between!(@challenger, @challenged)
    @settings = MatchSettings.from_params({ starting_score: 301, best_of_legs: 3, best_of_sets: 1 })
  end

  test "accepting creates the second authenticated player and starts existing invite flow" do
    challenge = Social::ChallengeManager.create(actor: @challenger, target: @challenged, settings: @settings)
    accepted, player = Social::ChallengeManager.accept(actor: @challenged, challenge: challenge)

    assert_equal "accepted", accepted.status
    assert_equal @challenged, player.user
    assert_equal 2, accepted.match.players.count
    assert accepted.match.invite_joined_at?
    assert accepted.match.match_sets.exists?
    assert_equal 301, accepted.match.starting_score
  end

  test "only recipient can accept and expired challenges cannot be accepted" do
    challenge = Social::ChallengeManager.create(actor: @challenger, target: @challenged, settings: @settings)
    assert_raises(Social::Error) { Social::ChallengeManager.accept(actor: @challenger, challenge: challenge) }

    travel_to 25.hours.from_now do
      error = assert_raises(Social::Error) do
        Social::ChallengeManager.accept(actor: @challenged, challenge: challenge)
      end
      assert_equal "conflict", error.code
      assert_equal "expired", challenge.reload.status
    end
  end

  test "challenge requires friendship and respects recipient preference" do
    Friendship.between(@challenger, @challenged).destroy!
    assert_raises(Social::Error) do
      Social::ChallengeManager.create(actor: @challenger, target: @challenged, settings: @settings)
    end

    Friendship.create_between!(@challenger, @challenged)
    @challenged.update!(challenge_policy: "nobody")
    error = assert_raises(Social::Error) do
      Social::ChallengeManager.create(actor: @challenger, target: @challenged, settings: @settings)
    end
    assert_equal "not_found", error.code
  end
end
