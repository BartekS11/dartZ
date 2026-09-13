require "test_helper"

class AdvancedMatchStatsTest < ActiveSupport::TestCase
  test "calculates scoring checkout consistency distribution and head to head metrics" do
    user = premium_user("advanced-stats@example.com")
    match, player, opponent, leg = build_match(user: user, starting_score: 101)
    turn = leg.turns.create!(player: player, completed_at: Time.current, total_score: 101)
    turn.throws.create!(segment: 20, multiplier: :triple)
    turn.throws.create!(segment: 1, multiplier: :single)
    turn.throws.create!(segment: 20, multiplier: :double)
    finish_match(match, leg, player, checkout_throws: 3)

    dashboard = AdvancedMatchStats.new(user: user)

    assert_equal({
      matches_played: 1,
      wins: 1,
      losses: 0,
      legs_won: 1,
      sets_won: 1,
      three_dart_average: 101.0,
      first_9_average: 101.0,
      highest_turn: 101,
      consistency: 0.0,
      best_match_average: 101.0,
      average_darts_per_won_leg: 3.0,
      bust_count: 0
    }, dashboard.summary)
    assert_equal 1, dashboard.distribution.find { |entry| entry[:band] == "100-119" }[:count]
    assert_equal 1, dashboard.checkouts[:opportunities]
    assert_equal 1, dashboard.checkouts[:completed]
    assert_equal 100.0, dashboard.checkouts[:percentage]
    assert_equal 101, dashboard.checkouts[:highest]
    assert_equal [ { route: "T20 1 D20", count: 1 } ], dashboard.checkouts[:routes]
    assert_nil dashboard.checkouts[:doubles_accuracy]
    assert_equal "target_intent_not_recorded", dashboard.checkouts[:doubles_accuracy_reason]
    assert_equal opponent.public_id, dashboard.head_to_head.first[:opponent_id]
    assert_equal 100.0, dashboard.coverage[:detailed_percentage]
  end

  test "reports turn-total coverage and treats an impossible total as a bust" do
    user = premium_user("advanced-total-only@example.com")
    _match, player, _opponent, leg = build_match(user: user, starting_score: 101)
    leg.turns.create!(player: player, completed_at: Time.current, total_score: 180)

    dashboard = AdvancedMatchStats.new(user: user)

    assert_equal 1, dashboard.summary[:bust_count]
    assert_equal 0.0, dashboard.summary[:three_dart_average]
    assert_equal 1, dashboard.coverage[:turn_total_only]
    assert_equal 0.0, dashboard.coverage[:detailed_percentage]
  end

  test "applies date opponent source rules and dart setup filters" do
    user = premium_user("advanced-filters@example.com")
    setup = user.create_dart_setup!(
      manufacturer: "target",
      weight_g: 24,
      shaft_type: "carbon",
      shaft_length_mm: 42,
      point_length_mm: 35
    )
    match, player, opponent, leg = build_match(user: user, starting_score: 301)
    player.assign_dart_setup_snapshot!(setup)
    player.save!
    turn = leg.turns.create!(player: player, completed_at: Time.current, total_score: 60)
    3.times { turn.throws.create!(segment: 20, multiplier: :single) }

    included = AdvancedMatchStats.new(user: user, filters: {
      from: Date.current,
      to: Date.current,
      starting_score: 301,
      opponent_id: opponent.public_id,
      match_source: "casual",
      dart_setup_id: setup.fingerprint,
      double_in: "false",
      double_out: "true"
    })
    excluded = AdvancedMatchStats.new(user: user, filters: { starting_score: 501 })

    assert_equal 1, included.summary[:matches_played]
    assert_equal 0, excluded.summary[:matches_played]
  end

  test "groups trend periods and exposes recent leg performance" do
    user = premium_user("advanced-trends@example.com")
    match, player, _opponent, leg = build_match(user: user, starting_score: 301)
    turn = leg.turns.create!(player: player, completed_at: Time.current, total_score: 60)
    3.times { turn.throws.create!(segment: 20, multiplier: :single) }

    dashboard = AdvancedMatchStats.new(user: user)

    assert_equal 1, dashboard.trends.size
    assert_equal 60.0, dashboard.trends.first[:average]
    assert_equal match.public_id, dashboard.leg_performance.first[:match_id]
    assert_equal leg.public_id, dashboard.leg_performance.first[:leg_id]
    assert_equal match.public_id, dashboard.set_performance.first[:match_id]
  end

  private

  def premium_user(email)
    create_user(email).tap { |user| user.update!(account_tier: "premium") }
  end

  def build_match(user:, starting_score:)
    match = Match.create!(starting_score: starting_score, best_of_legs: 1, best_of_sets: 1)
    player = match.players.create!(name: "Owner", user: user)
    opponent = match.players.create!(name: "Opponent")
    match_set = match.match_sets.create!
    leg = match_set.legs.create!(match: match)
    [ match, player, opponent, leg ]
  end

  def finish_match(match, leg, player, checkout_throws:)
    leg.update!(winner_id: player.id, checkout_throws: checkout_throws, finished_at: Time.current)
    leg.match_set.update!(winner_id: player.id, finished_at: Time.current)
    match.update!(winner_id: player.id, finished_at: Time.current)
  end
end
