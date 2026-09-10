require "test_helper"

class Admin::UserMetricsTest < ActiveSupport::TestCase
  setup do
    @user = create_user("metrics@example.com")
  end

  test "counts distinct wins losses invitations bots and latest match" do
    won = create_match_for(@user, created_at: 3.days.ago, finished: true, won: true)
    invitation = create_match_for(@user, created_at: 2.days.ago, finished: true, won: false, invitation: true)
    attach_to_tournament(invitation)
    bot = create_match_for(@user, created_at: 1.day.ago, bot: true)

    metrics = Admin::UserMetrics.for([ @user ]).fetch(@user)

    assert_equal 3, metrics[:matches]
    assert_equal 2, metrics[:completed]
    assert_equal 1, metrics[:in_progress]
    assert_equal 1, metrics[:wins]
    assert_equal 1, metrics[:losses]
    assert_equal 1, metrics[:invitations]
    assert_equal 1, metrics[:tournaments]
    assert_equal 1, metrics[:bots]
    assert_equal bot.created_at.to_i, metrics[:last_match_at].to_i
    assert won.finished_at
    assert invitation.finished_at
  end

  test "uses a bounded number of aggregate queries" do
    users = 3.times.map do |index|
      user = create_user("metrics-#{index}@example.com")
      create_match_for(user, created_at: index.days.ago)
      user
    end
    queries = []
    subscriber = lambda do |_name, _start, _finish, _id, payload|
      queries << payload[:sql] unless payload[:name] == "SCHEMA" || payload[:cached]
    end

    ActiveSupport::Notifications.subscribed(subscriber, "sql.active_record") do
      Admin::UserMetrics.for(users)
    end

    assert_operator queries.size, :<=, 4
  end

  private

  def attach_to_tournament(match)
    tournament = Tournament.create!(title: "Admin metrics", format_type: "groups")
    round = tournament.rounds.create!(name: "Round 1", number: 1, stage_type: "groups")
    tournament.tournament_matches.create!(tournament_round: round, linked_match: match, position: 1)
  end

  def create_match_for(user, created_at:, finished: false, won: false, invitation: false, bot: false)
    match = Match.create!(
      created_at: created_at,
      finished_at: (created_at + 1.hour if finished),
      invite_created_at: (created_at if invitation)
    )
    player = match.players.create!(name: "Player", user: user)
    match.players.create!(name: bot ? "Bot" : "Opponent", bot: bot)
    match.update_column(:winner_id, won ? player.id : match.players.where.not(id: player.id).pick(:id)) if finished
    match
  end
end
