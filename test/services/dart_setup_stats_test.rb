require "test_helper"

class DartSetupStatsTest < ActiveSupport::TestCase
  test "returns no setup stats for free users" do
    user = create_user("free-stats@example.com")

    assert_equal [], DartSetupStats.new(user: user).grouped
  end

  test "groups match stats by snapshotted dart setup for premium users" do
    user = create_user("premium-stats@example.com")
    user.update!(account_tier: "premium")
    setup = user.create_dart_setup!(
      manufacturer: "target",
      weight_g: 24.0,
      shaft_type: "carbon",
      shaft_length_mm: 42,
      point_length_mm: 35
    )

    match = Match.create!
    player = match.players.build(name: "Premium Player", user: user)
    player.assign_dart_setup_snapshot!(setup)
    player.save!
    match.players.create!(name: "Opponent")
    match.start_first_set!

    leg = match.current_leg
    turn = leg.turns.create!(player: player, completed_at: Time.current, total_score: 120)
    turn.throws.create!(segment: 20, multiplier: "triple")
    turn.throws.create!(segment: 20, multiplier: "double")
    turn.throws.create!(segment: 20, multiplier: "single")

    MatchStatePresenter.expects(:new).never
    stats = DartSetupStats.new(user: user).grouped

    assert_equal 1, stats.size
    setup_stats = stats.first
    assert_equal setup.fingerprint, setup_stats[:fingerprint]
    assert_equal "Target · 24g · Carbon · 42mm shaft · 35mm point", setup_stats[:setup]
    assert_equal 1, setup_stats[:matches]
    assert_equal 1, setup_stats[:completed_turns]
    assert_equal 3, setup_stats[:darts_thrown]
    assert_equal 120, setup_stats[:highest_turn]
    assert_equal 120.0, setup_stats[:average_per_turn]
    assert_equal 1, setup_stats[:double_hits]
    assert_equal 0, setup_stats[:checkout_chances]
    assert_equal 0, setup_stats[:checkout_hits]
    assert_equal 0.0, setup_stats[:checkout_rate]
  end

  test "groups multiple matches by immutable setup snapshots and orders by match count" do
    user = create_user("multiple-setup-stats@example.com")
    user.update!(account_tier: "premium")
    setup = user.create_dart_setup!(
      manufacturer: "target",
      weight_g: 24.0,
      shaft_type: "carbon",
      shaft_length_mm: 42,
      point_length_mm: 35
    )
    frequent_fingerprint = setup.fingerprint

    2.times { create_tracked_match(user, setup) }

    setup.update!(weight_g: 25.0)
    occasional_fingerprint = setup.fingerprint
    create_tracked_match(user, setup)

    stats = DartSetupStats.new(user: user).grouped

    assert_equal [ frequent_fingerprint, occasional_fingerprint ], stats.pluck(:fingerprint)
    assert_equal [ 2, 1 ], stats.pluck(:matches)
    assert_equal [ 0, 0 ], stats.pluck(:completed_turns)
    assert_equal [ 0.0, 0.0 ], stats.pluck(:average_per_turn)
  end

  private

  def create_tracked_match(user, setup)
    match = Match.create!
    player = match.players.build(name: "Setup Owner", user: user)
    player.assign_dart_setup_snapshot!(setup)
    player.save!
    match.players.create!(name: "Opponent")
    match.start_first_set!
    match
  end
end
