require "test_helper"

class TournamentTest < ActiveSupport::TestCase
  test "guest tournament is public by default and has tokens" do
    tournament = Tournament.create!(title: "Open Cup", format_type: "groups", best_of_legs: 3, best_of_sets: 1)

    assert tournament.guest_owned?
    assert_equal "public_guest", tournament.visibility
    assert tournament.share_token.present?
    assert tournament.admin_token.present?
    assert tournament.join_token.present?
  end

  test "logged in tournament defaults to participant only" do
    user = create_user("owner@example.com")
    tournament = Tournament.create!(title: "Club Night", format_type: "swiss", best_of_legs: 3, best_of_sets: 1, owner_user: user)

    assert_equal "participant_only", tournament.visibility
  end

  test "participant only tournament can be viewed by owner participant and join token holder" do
    owner = create_user("owner2@example.com")
    participant = create_user("participant@example.com")
    tournament = Tournament.create!(title: "Members", format_type: "swiss", best_of_legs: 3, best_of_sets: 1, owner_user: owner)
    tournament.entries.create!(name: "Participant", user: participant)

    assert tournament.can_view?(user: owner)
    assert tournament.can_view?(user: participant)
    assert tournament.can_view?(join_token: tournament.join_token)
    assert_not tournament.can_view?
  end
end
