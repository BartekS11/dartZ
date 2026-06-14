require "test_helper"

class MatchCleanupJobTest < ActiveJob::TestCase
  include ActiveSupport::Testing::TimeHelpers

  test "deletes only stale guest-only matches after guest retention window" do
    stale_guest = create_guest_match(updated_at: 4.days.ago)
    fresh_guest = create_guest_match(updated_at: 2.days.ago)
    stale_user  = create_user_match(updated_at: 2.years.ago)

    assert_difference("Match.count", -2) do
      MatchCleanupJob.perform_now
    end

    assert_not Match.exists?(stale_guest.id)
    assert Match.exists?(fresh_guest.id)
    assert_not Match.exists?(stale_user.id)
  end

  test "does not delete fresh user-backed matches before one year" do
    fresh_user_match = create_user_match(updated_at: 6.months.ago)
    fresh_mixed_match = create_mixed_match(updated_at: 10.days.ago)

    assert_no_difference("Match.count") do
      MatchCleanupJob.perform_now
    end

    assert Match.exists?(fresh_user_match.id)
    assert Match.exists?(fresh_mixed_match.id)
  end

  test "treats mixed guest and signed-in player matches as user-backed for retention" do
    stale_mixed_match = create_mixed_match(updated_at: 6.days.ago)

    assert_no_difference("Match.count") do
      MatchCleanupJob.perform_now
    end

    assert Match.exists?(stale_mixed_match.id)

    stale_mixed_match.update_columns(updated_at: 2.years.ago, created_at: 2.years.ago)

    assert_difference("Match.count", -1) do
      MatchCleanupJob.perform_now
    end

    assert_not Match.exists?(stale_mixed_match.id)
  end

  test "returns deleted count" do
    create_guest_match(updated_at: 4.days.ago)
    create_guest_match(updated_at: 5.days.ago)
    create_guest_match(updated_at: 1.day.ago)

    assert_equal 2, MatchCleanupJob.perform_now
  end

  test "deletes dependent records through destroy callbacks" do
    stale_match = create_guest_match(updated_at: 4.days.ago)
    stale_match.start_first_set!

    match_set = stale_match.match_sets.first
    leg = match_set.legs.first
    turn = leg.turns.first
    throw_record = turn.throws.create!(segment: 20, multiplier: :triple)

    assert_difference("Match.count", -1) do
      assert_difference("MatchSet.count", -1) do
        assert_difference("Leg.count", -1) do
          assert_difference("Turn.count", -1) do
            assert_difference("Throw.count", -1) do
              assert_difference("LegPlayer.count", -2) do
                assert_difference("Player.count", -2) do
                  MatchCleanupJob.perform_now
                end
              end
            end
          end
        end
      end
    end

    assert_not Match.exists?(stale_match.id)
    assert_not MatchSet.exists?(match_set.id)
    assert_not Leg.exists?(leg.id)
    assert_not Turn.exists?(turn.id)
    assert_not Throw.exists?(throw_record.id)
  end

  test "ignores matches when nothing is stale" do
    create_guest_match(updated_at: 12.hours.ago)
    create_user_match(updated_at: 2.months.ago)

    assert_no_difference("Match.count") do
      assert_equal 0, MatchCleanupJob.perform_now
    end
  end

  private

  def create_guest_match(updated_at:)
    match = Match.create!
    match.players.create!(name: "Guest 1")
    match.players.create!(name: "Guest 2")
    match.update_columns(created_at: updated_at, updated_at: updated_at)
    match
  end

  def create_user_match(updated_at:)
    user = create_user
    match = Match.create!
    match.players.create!(name: "Signed In", user: user)
    match.players.create!(name: "Guest")
    match.update_columns(created_at: updated_at, updated_at: updated_at)
    match
  end

  def create_mixed_match(updated_at:)
    user = create_user
    match = Match.create!
    match.players.create!(name: "Signed In", user: user)
    match.players.create!(name: "Guest")
    match.update_columns(created_at: updated_at, updated_at: updated_at)
    match
  end

  def create_user
    User.create!(
      email_address: "user-#{SecureRandom.hex(4)}@example.com",
      password: "password",
      password_confirmation: "password"
    )
  end
end
