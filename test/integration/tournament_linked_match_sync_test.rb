require "test_helper"

class TournamentLinkedMatchSyncTest < ActionDispatch::IntegrationTest
  test "finishing launched tournament match syncs tournament score and standings" do
    tournament, tournament_match = build_tournament_fixture

    post launch_tournament_tournament_match_path(tournament, tournament_match, admin_token: tournament.admin_token)

    linked_match = tournament_match.reload.linked_match
    assert_redirected_to match_path(linked_match, guest_token: linked_match.guest_token)
    assert_equal "live", tournament_match.status

    winning_turn = linked_match.current_leg.current_turn
    assert_equal tournament_match.home_entry.name, winning_turn.player.name
    winning_turn.leg.leg_players.find_by!(player: winning_turn.player).update!(score: 60)

    post turn_throws_path(winning_turn), params: {
      throw: { total: 60, segment: 20, multiplier: "triple" }
    }

    tournament_match.reload
    tournament.reload

    assert_equal "complete", tournament_match.status
    assert_equal tournament_match.home_entry, tournament_match.winner_entry
    assert_equal 1, tournament_match.home_legs
    assert_equal 0, tournament_match.away_legs
    assert_equal 1, tournament_match.home_sets
    assert_equal 0, tournament_match.away_sets

    home = tournament_match.home_entry.reload
    away = tournament_match.away_entry.reload
    assert_equal 1, home.wins
    assert_equal 0, home.losses
    assert_equal 1, home.points
    assert_equal 1, home.legs_for
    assert_equal 0, home.legs_against
    assert_equal 0, away.wins
    assert_equal 1, away.losses
    assert_equal 0, away.points
    assert_equal 0, away.legs_for
    assert_equal 1, away.legs_against

    get match_path(linked_match, guest_token: linked_match.guest_token)
    assert_response :success
    assert_select "a[href=?]", live_tournament_path(tournament, share_token: tournament.share_token), text: "Back to tournament"
  end

  test "logged in tournament owner can score launched guest match" do
    owner = create_user("owner-linked-sync@example.com")
    tournament, tournament_match = build_tournament_fixture(owner_user: owner)

    login_as(owner)
    post launch_tournament_tournament_match_path(tournament, tournament_match)

    linked_match = tournament_match.reload.linked_match
    assert_redirected_to match_path(linked_match, guest_token: linked_match.guest_token)

    winning_turn = linked_match.current_leg.current_turn
    winning_turn.leg.leg_players.find_by!(player: winning_turn.player).update!(score: 60)

    post turn_throws_path(winning_turn), params: {
      throw: { total: 60, segment: 20, multiplier: "triple" }
    }

    assert_response :redirect
    assert_equal "complete", tournament_match.reload.status
  end

  test "creating and finishing a normal match does not update tournament fixture" do
    tournament, tournament_match = build_tournament_fixture

    post launch_tournament_tournament_match_path(tournament, tournament_match, admin_token: tournament.admin_token)
    linked_match = tournament_match.reload.linked_match
    assert_not_nil linked_match

    post matches_path, params: {
      player1_name: tournament_match.home_entry.name,
      player2_name: tournament_match.away_entry.name,
      starting_score: 101,
      best_of_legs: 1,
      best_of_sets: 1,
      double_out: "0"
    }

    normal_match = Match.order(:created_at).last
    refute_equal linked_match.id, normal_match.id
    refute_equal tournament_match.id, TournamentMatch.find_by(linked_match: normal_match)&.id

    winning_turn = normal_match.current_leg.current_turn
    winning_turn.leg.leg_players.find_by!(player: winning_turn.player).update!(score: 60)
    post turn_throws_path(winning_turn), params: {
      throw: { total: 60, segment: 20, multiplier: "triple" }
    }

    tournament_match.reload
    assert_equal "live", tournament_match.status
    assert_nil tournament_match.winner_entry
    assert_equal 0, tournament_match.home_legs
    assert_equal 0, tournament_match.away_legs

    get match_path(normal_match, guest_token: normal_match.guest_token)
    assert_response :success
    assert_select "a", { text: "Back to tournament", count: 0 }
  end

  private

  def build_tournament_fixture(owner_user: nil)
    tournament = Tournament.create!(
      title: "Linked Sync Cup",
      format_type: "groups",
      best_of_legs: 1,
      best_of_sets: 1,
      starting_score: 101,
      double_out: false,
      seeding_mode: "manual",
      owner_user: owner_user
    )
    home = tournament.entries.create!(name: "Alpha", seed: 1, group_name: "A")
    away = tournament.entries.create!(name: "Bravo", seed: 2, group_name: "A")
    round = tournament.rounds.create!(number: 1, name: "Group A", stage_type: "groups", group_name: "A", status: "active")
    tournament_match = round.tournament_matches.create!(
      tournament: tournament,
      home_entry: home,
      away_entry: away,
      position: 1,
      best_of_legs: 1,
      best_of_sets: 1,
      starting_score: 101,
      double_out: false
    )

    [ tournament, tournament_match ]
  end
end
