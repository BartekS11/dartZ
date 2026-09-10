require "test_helper"

class MatchStatePresenterTest < ActiveSupport::TestCase
  test "active match payloads preserve display order and complete structures" do
    match, alice, bob = build_active_multi_set_match
    match.update!(player_display_reversed: true)

    presenter = MatchStatePresenter.new(match.reload)

    assert_equal [ bob, alice ], presenter.players
    assert_equal alice, presenter.current_player
    assert_equal alice.id, presenter.current_player.id
    assert_equal 241, presenter.score_for(alice.id)
    assert_equal 201, presenter.score_for(bob)
    assert_equal 26.0, presenter.three_dart_average(alice)
    assert_equal 100.0, presenter.three_dart_average(bob)
    assert_equal 1, presenter.sets_won_by(alice)
    assert_equal 0, presenter.sets_won_by(bob)
    assert_equal 0, presenter.legs_won_by(alice)
    assert_equal 1, presenter.legs_won_by(bob)
    assert presenter.needs_double_in?(alice)
    assert_not presenter.needs_double_in?(bob)

    assert_equal({
      id: match.public_id,
      match_identifier: match.match_identifier,
      ui_identifier: match.ui_identifier,
      finished: false,
      starting_score: 301,
      game_mode_labels: match.game_mode_labels,
      players: [
        { id: bob.public_id, name: "Bob", score: 201, avg: 100.0, winner: false },
        { id: alice.public_id, name: "Alice", score: 241, avg: 26.0, winner: false }
      ]
    }, presenter.summary_payload)

    assert_equal({
      id: match.public_id,
      match_identifier: match.match_identifier,
      ui_identifier: match.ui_identifier,
      finished: false,
      best_of_legs: 3,
      best_of_sets: 3,
      starting_score: 301,
      double_in: true,
      double_out: true,
      winner: nil,
      current_player: "Alice",
      current_turn_id: presenter.current_turn.public_id,
      players: [
        {
          id: bob.public_id,
          name: "Bob",
          score: 201,
          avg: 100.0,
          sets_won: 0,
          legs_won: 1,
          winner: false,
          last_throws: [
            { segment: 20, multiplier: "triple", points: 60 },
            { segment: 20, multiplier: "single", points: 20 },
            { segment: 20, multiplier: "single", points: 20 }
          ],
          checkout: nil
        },
        {
          id: alice.public_id,
          name: "Alice",
          score: 241,
          avg: 26.0,
          sets_won: 1,
          legs_won: 0,
          winner: false,
          last_throws: [ { segment: 20, multiplier: "triple", points: 60 } ],
          checkout: nil
        }
      ]
    }, presenter.state_payload)
  end

  test "detailed statistics preserve persisted totals calculated totals incomplete turns and checkout rules" do
    match = Match.create!(starting_score: 301, best_of_legs: 3)
    alice = match.players.create!(name: "Alice")
    bob = match.players.create!(name: "Bob")
    match_set = match.match_sets.create!

    winning_leg = match_set.legs.create!(match:, winner_id: alice.id, finished_at: Time.current, checkout_throws: 2)
    persisted_turn = create_turn(winning_leg, alice, [ [ 20, :triple ], [ 20, :single ], [ 20, :single ] ], total_score: 180)
    calculated_turn = create_turn(winning_leg, alice, [ [ 20, :triple ], [ 20, :triple ], [ 1, :single ] ], total_score: nil)
    create_turn(winning_leg, bob, [ [ 20, :single ], [ 20, :single ], [ 20, :single ] ], total_score: nil)

    slower_winning_leg = match_set.legs.create!(match:, winner_id: alice.id, finished_at: Time.current, checkout_throws: 3)
    3.times { create_turn(slower_winning_leg, alice, [ [ 20, :single ], [ 20, :single ], [ 20, :single ] ], total_score: 60) }

    active_leg = match_set.legs.create!(match:)
    last_completed = create_turn(active_leg, alice, [ [ 5, :single ], [ 20, :single ] ], total_score: nil)
    create_turn(active_leg, bob, [ [ 20, :single ] ], total_score: nil, completed: false)
    active_turn = create_turn(active_leg, alice, [ [ 19, :triple ] ], total_score: nil, completed: false)

    presenter = MatchStatePresenter.new(match.reload)
    stats = presenter.stats_for(alice.id)

    assert_equal 180, presenter.turn_total(persisted_turn)
    assert_equal 121, presenter.turn_total(calculated_turn)
    assert_equal 25, presenter.last_turn_total_for(alice)
    assert_equal active_turn.public_id, presenter.current_turn.public_id
    assert_equal [ 57 ], presenter.last_turn_throws_for(alice).map(&:points)
    assert_equal [ 57, 20, 5 ], presenter.last_throws_for(alice).map(&:points)
    assert_equal last_completed.id, stats[:last_completed_turn_in_current_leg].id
    assert_equal 6, stats[:completed_turns].size
    assert_equal 18, stats[:darts_thrown]
    assert_equal 180, stats[:highest_turn]
    assert_equal 120.3, stats[:first_nine_avg]
    assert_equal 2, stats[:ton_plus]
    assert_equal 1, stats[:one_forty_plus]
    assert_equal 1, stats[:one_eighty]
    assert_equal({ single: 14, triple: 4 }, stats[:split].slice("single", "triple").symbolize_keys)
    assert_equal({ chances: 1, hits: 2, rate: 200.0, average_darts: 2.5 }, stats[:checkout])
    assert_equal winning_leg.id, stats[:best_leg].id
    assert_equal 6, stats[:best_leg_darts]
    assert_equal [ 25, 60, 60, 60, 121 ], stats[:recent_turns].map { |turn| presenter.turn_total(turn) }
    assert_equal [ 20, 5 ], stats[:previous_turn_throws].map(&:points)
    assert_equal 84.3, presenter.average_per_turn(alice)
    assert_equal presenter.stats_for(alice), presenter.stats_for(alice.id)
  end

  test "finished multi-set match uses all completed turns final set wins and set winner" do
    match, alice, bob = build_active_multi_set_match
    current_set = match.match_sets.order(:created_at).last
    current_leg = current_set.legs.order(:created_at).last
    active_turn = current_leg.turns.order(:created_at).last
    active_turn.update!(completed_at: Time.current, total_score: 60)
    current_leg.update!(finished_at: Time.current, winner_id: bob.id, checkout_throws: 1)
    current_set.update!(finished_at: Time.current, winner_id: bob.id)
    match.update!(finished_at: Time.current, winner_id: bob.id)

    presenter = MatchStatePresenter.new(match.reload)

    assert presenter.finished?
    assert_nil presenter.current_set
    assert_nil presenter.current_leg
    assert_nil presenter.current_turn
    assert_nil presenter.current_player
    assert_equal bob, presenter.winner
    assert_equal 2, presenter.legs_won_by(bob)
    assert_equal 0, presenter.legs_won_by(alice)
    assert_equal 1, presenter.sets_won_by(alice)
    assert_equal 1, presenter.sets_won_by(bob)
    assert_equal 57.8, presenter.three_dart_average(alice)
    assert_equal 100.0, presenter.three_dart_average(bob)
    assert_equal [], presenter.last_turn_throws_for(alice)
    assert_nil presenter.last_turn_total_for(alice)
    assert_equal "Bob", presenter.summary_payload[:players].find { |payload| payload[:winner] }[:name]
    assert_equal "Bob", presenter.state_payload[:winner]
    assert_nil presenter.state_payload[:current_turn_id]
  end

  test "summary and state payloads do not instantiate detailed player statistics" do
    match = Match.create!
    match.players.create!(name: "Alice")
    match.players.create!(name: "Bob")
    match.start_first_set!

    MatchPresentation::PlayerStats.expects(:new).never

    presenter = MatchStatePresenter.new(match.reload)
    presenter.summary_payload
    presenter.state_payload
  end

  private

  def build_active_multi_set_match
    match = Match.create!(starting_score: 301, best_of_legs: 3, best_of_sets: 3, double_in: true, double_out: true)
    alice = match.players.create!(name: "Alice")
    bob = match.players.create!(name: "Bob")

    finished_set = match.match_sets.create!(finished_at: Time.current, winner_id: alice.id)
    finished_leg = finished_set.legs.create!(match:, finished_at: Time.current, winner_id: alice.id, checkout_throws: 2)
    create_turn(finished_leg, alice, [ [ 20, :triple ], [ 20, :single ], [ 20, :single ] ], total_score: 100)
    create_turn(finished_leg, bob, [ [ 20, :single ], [ 20, :single ], [ 20, :single ] ], total_score: nil)

    active_set = match.match_sets.create!
    finished_active_set_leg = active_set.legs.create!(match:, finished_at: Time.current, winner_id: bob.id, checkout_throws: 3)
    create_turn(finished_active_set_leg, alice, [ [ 15, :single ], [ 15, :single ], [ 15, :single ] ], total_score: 45)
    create_turn(finished_active_set_leg, bob, [ [ 20, :triple ], [ 20, :triple ], [ 20, :single ] ], total_score: 140)

    active_leg = active_set.legs.create!(match:)
    active_leg.leg_players.find_by!(player: alice).update!(score: 241, has_doubled_in: false)
    active_leg.leg_players.find_by!(player: bob).update!(score: 201, has_doubled_in: true)
    create_turn(active_leg, alice, [ [ 20, :single ], [ 5, :single ], [ 1, :single ] ], total_score: nil)
    create_turn(active_leg, bob, [ [ 20, :triple ], [ 20, :single ], [ 20, :single ] ], total_score: 100)
    create_turn(active_leg, alice, [ [ 20, :triple ] ], total_score: nil, completed: false)

    [ match, alice, bob ]
  end

  def create_turn(leg, player, throws, total_score:, completed: true)
    turn = leg.turns.create!(
      player:,
      total_score:,
      completed_at: completed ? Time.current : nil
    )
    throws.each { |segment, multiplier| turn.throws.create!(segment:, multiplier:) }
    turn
  end
end
