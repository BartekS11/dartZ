require "test_helper"

class MatchPlayerOrderingTest < ActiveSupport::TestCase
  test "new and existing matches retain creation display order by default" do
    match = Match.create!
    first = match.players.create!(name: "Alice")
    second = match.players.create!(name: "Bob")

    refute match.player_display_reversed?
    assert_equal [ first, second ], match.players_in_display_order.to_a
  end

  test "swap changes the empty current turn player without moving player cards or scores" do
    match, alice, bob = started_match
    turn = match.current_leg.current_turn
    scores = { alice.id => match.score_for(alice), bob.id => match.score_for(bob) }

    assert match.swap_current_thrower

    match.reload
    assert_equal [ alice, bob ], match.players_in_display_order.to_a
    assert_equal turn.id, match.current_leg.current_turn.id
    assert_equal bob, match.current_player
    assert_equal scores, { alice.id => match.score_for(alice), bob.id => match.score_for(bob) }

    ThrowSubmission.call(turn: match.current_leg.current_turn, total: 45)
    assert_equal alice, match.reload.current_player
    assert_equal [ alice, bob ], match.players_in_display_order.to_a
  end

  test "swap is available during the first three turns and unavailable from turn four" do
    match, = started_match

    assert match.player_thrower_swappable?
    ThrowSubmission.call(turn: match.current_leg.current_turn, total: 0)
    assert match.reload.player_thrower_swappable?
    ThrowSubmission.call(turn: match.current_leg.current_turn, total: 0)
    assert match.reload.player_thrower_swappable?
    ThrowSubmission.call(turn: match.current_leg.current_turn, total: 0)

    refute match.reload.player_thrower_swappable?
    refute match.swap_current_thrower
  end

  test "swap is unavailable after a dart is entered in the current turn" do
    match, alice, = started_match
    turn = match.current_leg.current_turn
    ThrowSubmission.call(turn: turn, throw_attributes: { segment: 20, multiplier: "single" })

    refute match.reload.player_thrower_swappable?
    refute match.swap_current_thrower
    assert_equal alice, match.reload.current_player
  end

  test "swap is unavailable before start after finish or without exactly two players" do
    unstarted = Match.create!
    unstarted.players.create!(name: "Alice")
    unstarted.players.create!(name: "Bob")
    refute unstarted.player_thrower_swap_context?
    refute unstarted.swap_current_thrower

    finished, = started_match
    finished.update!(finished_at: Time.current)
    refute finished.player_thrower_swap_context?
    refute finished.swap_current_thrower

    three_player_match, = started_match
    three_player_match.players.create!(name: "Cara")
    refute three_player_match.player_thrower_swap_context?
    refute three_player_match.swap_current_thrower
  end

  test "only the original first player's user can see the invite swap control" do
    host = create_user("swap-host-model@example.com")
    invitee = create_user("swap-invitee-model@example.com")
    match, = started_match(invite_token: SecureRandom.urlsafe_base64(24), invite_joined_at: Time.current)
    match.players.reorder(:created_at, :id).first.update!(user: host)
    match.players.reorder(:created_at, :id).second.update!(user: invitee)

    assert match.invite_host?(host)
    assert match.player_thrower_swap_visible_by?(user: host)
    refute match.invite_host?(invitee)
    refute match.player_thrower_swap_visible_by?(user: invitee)

    assert match.swap_current_thrower
    assert match.reload.invite_host?(host)
  end

  test "swapping to a bot enqueues its turn" do
    match = Match.create!
    match.players.create!(name: "Human")
    bot = match.players.create!(name: "Bot", bot: true, bot_level: 10)
    match.start_first_set!

    BotTurnJob.expects(:perform_later).with(match.current_leg.current_turn.id).once

    assert match.swap_current_thrower
    assert_equal bot, match.reload.current_player
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
