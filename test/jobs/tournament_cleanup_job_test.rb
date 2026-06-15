require "test_helper"

class TournamentCleanupJobTest < ActiveJob::TestCase
  test "deletes stale guest tournaments after three months" do
    stale_guest = create_guest_tournament(updated_at: 4.months.ago)
    fresh_guest = create_guest_tournament(updated_at: 2.months.ago)
    stale_user = create_user_tournament(updated_at: 2.years.ago)

    assert_difference("Tournament.count", -2) do
      TournamentCleanupJob.perform_now
    end

    assert_not Tournament.exists?(stale_guest.id)
    assert Tournament.exists?(fresh_guest.id)
    assert_not Tournament.exists?(stale_user.id)
  end

  test "does not delete logged in tournaments before one year" do
    fresh_user = create_user_tournament(updated_at: 6.months.ago)

    assert_no_difference("Tournament.count") do
      TournamentCleanupJob.perform_now
    end

    assert Tournament.exists?(fresh_user.id)
  end

  test "returns deleted count" do
    create_guest_tournament(updated_at: 4.months.ago)
    create_guest_tournament(updated_at: 5.months.ago)
    create_user_tournament(updated_at: 2.months.ago)

    assert_equal 2, TournamentCleanupJob.perform_now
  end

  test "deletes dependent tournament records" do
    stale = create_guest_tournament(updated_at: 4.months.ago)
    entry = stale.entries.create!(name: "Player 1", seed: 1)
    round = stale.rounds.create!(number: 1, name: "Round 1", stage_type: "playoffs", bracket: "upper", status: "active")
    match = stale.tournament_matches.create!(tournament_round: round, home_entry: entry, position: 1, best_of_legs: 3, best_of_sets: 1, bye: true, winner_entry: entry, status: "complete")

    assert_difference("Tournament.count", -1) do
      assert_difference("TournamentEntry.count", -1) do
        assert_difference("TournamentRound.count", -1) do
          assert_difference("TournamentMatch.count", -1) do
            TournamentCleanupJob.perform_now
          end
        end
      end
    end

    assert_not Tournament.exists?(stale.id)
    assert_not TournamentEntry.exists?(entry.id)
    assert_not TournamentRound.exists?(round.id)
    assert_not TournamentMatch.exists?(match.id)
  end

  private

  def create_guest_tournament(updated_at:)
    tournament = Tournament.create!(title: "Guest #{SecureRandom.hex(2)}", format_type: "groups", best_of_legs: 3, best_of_sets: 1)
    tournament.update_columns(created_at: updated_at, updated_at: updated_at)
    tournament
  end

  def create_user_tournament(updated_at:)
    user = create_user("user-#{SecureRandom.hex(4)}@example.com")
    tournament = Tournament.create!(title: "User #{SecureRandom.hex(2)}", format_type: "swiss", best_of_legs: 3, best_of_sets: 1, owner_user: user)
    tournament.update_columns(created_at: updated_at, updated_at: updated_at)
    tournament
  end
end
