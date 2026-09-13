require "test_helper"

class Admin::AccountDataCleanupTest < ActiveSupport::TestCase
  setup do
    @admin = AdminUser.create!(email_address: "cleanup-admin@example.com", password: "a-secure-password-123")
    @user = create_user("cleanup-user@example.com")
  end

  test "clear detaches only finished matches and restore reconnects the entire batch" do
    finished = Match.create!(finished_at: Time.current)
    player = finished.players.create!(name: "Owner", user: @user)
    opponent = finished.players.create!(name: "Opponent")
    active = Match.create!
    active_player = active.players.create!(name: "Owner", user: @user)

    cleanup = clear!(%w[matches])

    assert_nil player.reload.user_id
    assert_equal cleanup, player.admin_data_cleanup
    assert_equal @user, active_player.reload.user
    assert_equal opponent, finished.reload.players.find(opponent.id)
    assert_equal({ "matches" => 1 }, cleanup.counts)

    restore!(cleanup)

    assert_equal @user, player.reload.user
    assert_nil player.admin_data_cleanup_id
    assert_equal "restored", cleanup.reload.status
  end

  test "clear all excludes active activity and keeps account and billing state" do
    @user.update!(stripe_customer_id: "cus_cleanup", manual_tier_override: "premium")
    login_session = @user.sessions.create!
    completed_session = @user.training_sessions.create!(mode: "around_the_clock", status: "completed", completed_at: Time.current)
    active_session = @user.training_sessions.create!(mode: "around_the_clock")
    completed_plan = @user.practice_plans.create!(title: "Done", plan_type: "custom", status: "completed", completed_at: Time.current)
    active_plan = @user.practice_plans.create!(title: "Active", plan_type: "custom")

    cleanup = clear!([ "all" ])

    assert_equal cleanup, completed_session.reload.admin_data_cleanup
    assert_nil active_session.reload.admin_data_cleanup_id
    assert_equal cleanup, completed_plan.reload.admin_data_cleanup
    assert_nil active_plan.reload.admin_data_cleanup_id
    assert_equal "cus_cleanup", @user.reload.stripe_customer_id
    assert_equal "premium", @user.manual_tier_override
    assert Session.exists?(login_session.id)
  end

  test "completed tournaments are detached and preserved for restore" do
    tournament = Tournament.create!(title: "Cleanup Cup", format_type: "playoffs", status: "complete", owner_user: @user)
    entry = tournament.entries.create!(name: "Owner", user: @user)

    cleanup = clear!(%w[tournaments])

    assert_nil tournament.reload.owner_user_id
    assert_nil entry.reload.user_id
    assert_equal cleanup, tournament.owner_admin_data_cleanup
    assert_equal cleanup, entry.admin_data_cleanup
    assert Tournament.exists?(tournament.id)

    restore!(cleanup)

    assert_equal @user, tournament.reload.owner_user
    assert_equal @user, entry.reload.user
  end

  test "purge is allowed only for cleared batches and preserves detached shared match" do
    match = Match.create!(finished_at: Time.current)
    player = match.players.create!(name: "Owner", user: @user)
    cleanup = clear!(%w[matches])

    purge!(cleanup)

    assert Match.exists?(match.id)
    assert Player.exists?(player.id)
    assert_nil player.reload.user_id
    assert_nil player.admin_data_cleanup_id
    assert_equal "purged", cleanup.reload.status
    assert_raises(Admin::AccountDataCleanup::InvalidTransition) { purge!(cleanup) }
  end

  test "new setup blocks whole-batch restore without partial changes" do
    old_setup = @user.create_dart_setup!(manufacturer: "winmau", weight_g: 23, shaft_type: "nylon", shaft_length_mm: 40, point_length_mm: 32)
    session = @user.training_sessions.create!(mode: "around_the_clock", status: "completed", completed_at: Time.current)
    cleanup = clear!(%w[dart_setup training_sessions])
    @user.create_dart_setup!(manufacturer: "target", weight_g: 24, shaft_type: "carbon", shaft_length_mm: 41, point_length_mm: 33)

    assert_raises(Admin::AccountDataCleanup::RestoreConflict) { restore!(cleanup) }

    assert_equal cleanup, old_setup.reload.admin_data_cleanup
    assert_equal cleanup, session.reload.admin_data_cleanup
    assert_equal "cleared", cleanup.reload.status
    assert_equal 1, cleanup.events.count
  end

  test "confirmation and reason are required" do
    assert_raises(Admin::AccountDataCleanup::ConfirmationError) do
      Admin::AccountDataCleanup.clear!(user: @user, admin_user: @admin, categories: %w[matches], reason: "", confirmation_email: @user.email_address, acknowledged: "1")
    end
    assert_raises(Admin::AccountDataCleanup::ConfirmationError) do
      Admin::AccountDataCleanup.clear!(user: @user, admin_user: @admin, categories: %w[matches], reason: "Requested", confirmation_email: "wrong@example.com", acknowledged: "1")
    end
  end

  private

  def clear!(categories)
    Admin::AccountDataCleanup.clear!(user: @user, admin_user: @admin, categories: categories,
      reason: "Support request", confirmation_email: @user.email_address, acknowledged: "1")
  end

  def restore!(cleanup)
    Admin::AccountDataCleanup.restore!(cleanup: cleanup, admin_user: @admin,
      reason: "Request reversed", confirmation_email: @user.email_address, acknowledged: "1")
  end

  def purge!(cleanup)
    Admin::AccountDataCleanup.purge!(cleanup: cleanup, admin_user: @admin,
      reason: "Retention expired", confirmation_email: @user.email_address, acknowledged: "1")
  end
end
