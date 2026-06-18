require "test_helper"

class TournamentsControllerTest < ActionDispatch::IntegrationTest
  test "guest can create public tournament" do
    assert_difference("Tournament.count", 1) do
      post tournaments_path, params: {
        tournament: {
          title: "Guest Open",
          format_type: "groups",
          best_of_legs: 3,
          best_of_sets: 1,
          group_count: 2,
          entry_names: "Alice\nBob\nCara\nDan"
        }
      }
    end

    tournament = Tournament.order(:created_at).last
    assert_redirected_to tournament_path(tournament, admin_token: tournament.admin_token)
    assert_equal "public_guest", tournament.visibility
  end

  test "logged in owner can view participant only tournament and outsider cannot" do
    owner = create_user("owner@test.com")
    outsider = create_user("outsider@test.com")
    tournament = Tournament.create!(title: "Private Cup", format_type: "swiss", best_of_legs: 3, best_of_sets: 1, owner_user: owner)
    tournament.entries.create!(name: "Owner", user: owner)

    login_as(owner)
    get tournament_path(tournament)
    assert_response :success

    delete session_path
    login_as(outsider)
    get tournament_path(tournament)
    assert_redirected_to tournaments_path
  end

  test "admin can reseed tournament" do
    tournament = Tournament.create!(title: "Reseed Cup", format_type: "playoffs", best_of_legs: 3, best_of_sets: 1)
    tournament.entries.create!(name: "C", seed: 9)
    tournament.entries.create!(name: "A", seed: 7)
    tournament.entries.create!(name: "B", seed: 5)

    post reseed_tournament_path(tournament, admin_token: tournament.admin_token)

    assert_redirected_to tournament_path(tournament, admin_token: tournament.admin_token)
    assert_equal [ 1, 2, 3 ], tournament.reload.entries.order(:created_at).pluck(:seed)
  end

  test "guest admin can update tournament settings" do
    tournament = Tournament.create!(title: "Editable Cup", format_type: "swiss", best_of_legs: 3, best_of_sets: 1)
    tournament.entries.create!(name: "A", seed: 1)
    tournament.entries.create!(name: "B", seed: 2)

    patch tournament_path(tournament, admin_token: tournament.admin_token), params: {
      tournament: {
        title: "Updated Cup",
        best_of_legs: 5,
        swiss_round_count: 4
      }
    }

    assert_redirected_to tournament_path(tournament, admin_token: tournament.admin_token)
    tournament.reload
    assert_equal "Updated Cup", tournament.title
    assert_equal 5, tournament.best_of_legs
    assert_equal 4, tournament.swiss_round_count
  end

  test "guest admin can delete tournament" do
    tournament = Tournament.create!(title: "Delete Me", format_type: "groups", best_of_legs: 3, best_of_sets: 1)

    assert_difference("Tournament.count", -1) do
      delete tournament_path(tournament, admin_token: tournament.admin_token)
    end

    assert_redirected_to tournaments_path
  end
end
