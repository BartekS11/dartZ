require "test_helper"

class MatchPlayerOrderingTest < ActiveSupport::TestCase
  test "new and existing matches retain creation display order by default" do
    match = Match.create!
    first = match.players.create!(name: "Alice")
    second = match.players.create!(name: "Bob")

    refute match.player_display_reversed?
    assert_equal [ first, second ], match.players_in_display_order.to_a
  end

  test "swap reverses display order without changing gameplay state" do
    match, alice, bob = started_match
    alice_turn = match.current_leg.current_turn
    ThrowSubmission.call(turn: alice_turn, total: 60)
    bob_turn = match.reload.current_leg.current_turn

    player_ids = match.players.reorder(:created_at, :id).pluck(:id)
    scores = { alice.id => match.score_for(alice), bob.id => match.score_for(bob) }
    turn_ids = match.turns.order(:created_at).pluck(:id, :player_id)

    assert match.swap_player_display_order

    match.reload
    assert_equal [ bob, alice ], match.players_in_display_order.to_a
    assert_equal player_ids, match.players.reorder(:created_at, :id).pluck(:id)
    assert_equal scores, { alice.id => match.score_for(alice), bob.id => match.score_for(bob) }
    assert_equal turn_ids, match.turns.order(:created_at).pluck(:id, :player_id)
    assert_equal bob, match.current_player
    assert_equal bob_turn.id, match.current_leg.current_turn.id

    ThrowSubmission.call(turn: bob_turn, total: 45)
    assert_equal alice, match.reload.current_player
    assert_equal [ bob, alice ], match.players_in_display_order.to_a
  end

  test "repeated swaps toggle persisted display order" do
    match, alice, bob = started_match

    2.times { assert match.swap_player_display_order }

    refute match.reload.player_display_reversed?
    assert_equal [ alice, bob ], match.players_in_display_order.to_a
  end

  test "swap is unavailable before start after finish or without exactly two players" do
    unstarted = Match.create!
    unstarted.players.create!(name: "Alice")
    unstarted.players.create!(name: "Bob")
    refute unstarted.player_display_swappable?
    refute unstarted.swap_player_display_order

    finished, = started_match
    finished.update!(finished_at: Time.current)
    refute finished.player_display_swappable?
    refute finished.swap_player_display_order

    three_player_match, = started_match
    three_player_match.players.create!(name: "Cara")
    refute three_player_match.player_display_swappable?
    refute three_player_match.swap_player_display_order
  end

  test "only the original first player's user is the invite host" do
    host = create_user("swap-host-model@example.com")
    invitee = create_user("swap-invitee-model@example.com")
    match, = started_match(invite_token: SecureRandom.urlsafe_base64(24), invite_joined_at: Time.current)
    match.players.reorder(:created_at, :id).first.update!(user: host)
    match.players.reorder(:created_at, :id).second.update!(user: invitee)

    assert match.invite_host?(host)
    assert match.player_display_swappable_by?(user: host)
    refute match.invite_host?(invitee)
    refute match.player_display_swappable_by?(user: invitee)

    match.swap_player_display_order
    assert match.reload.invite_host?(host)
  end

  private
    def started_match(**attributes)
      match = Match.create!(**attributes)
      alice = match.players.create!(name: "Alice")
      bob = match.players.create!(name: "Bob")
      match.start_first_set!
      [ match, alice, bob ]
    end
end
