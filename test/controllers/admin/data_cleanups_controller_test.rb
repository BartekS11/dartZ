require "test_helper"

class Admin::DataCleanupsControllerTest < ActionDispatch::IntegrationTest
  setup do
    @admin = AdminUser.create!(email_address: "data-admin@example.com", password: "a-secure-password-123")
    @user = create_user("data-user@example.com")
    post admin_login_path, params: { email_address: @admin.email_address, password: "a-secure-password-123" }
  end

  test "creates an audited cleanup through the hidden admin namespace" do
    match = Match.create!(finished_at: Time.current)
    player = match.players.create!(name: "Player", user: @user)

    post admin_user_data_cleanups_path(@user), params: confirmed_params.merge(categories: %w[matches])

    assert_redirected_to admin_user_path(@user)
    cleanup = @user.admin_data_cleanups.last
    assert_equal "cleared", cleanup.status
    assert_nil player.reload.user_id
    assert_equal "Support request", cleanup.events.last.reason
  end

  test "rejects requests without second confirmation" do
    post admin_user_data_cleanups_path(@user), params: confirmed_params.merge(categories: %w[matches], confirmation_acknowledgement: "")

    assert_redirected_to admin_user_path(@user)
    assert_empty @user.admin_data_cleanups
  end

  test "restores and purges only batches belonging to the scoped user" do
    match = Match.create!(finished_at: Time.current)
    match.players.create!(name: "Player", user: @user)
    post admin_user_data_cleanups_path(@user), params: confirmed_params.merge(categories: %w[matches])
    cleanup = @user.admin_data_cleanups.last

    patch restore_admin_user_data_cleanup_path(@user, cleanup), params: confirmed_params
    assert_redirected_to admin_user_path(@user)
    assert_equal "restored", cleanup.reload.status

    other_user = create_user("other-data-user@example.com")
    delete purge_admin_user_data_cleanup_path(other_user, cleanup), params: confirmed_params.merge(confirmation_email: other_user.email_address)

    assert_response :not_found
    assert_equal "restored", cleanup.reload.status
  end

  private

  def confirmed_params
    { reason: "Support request", confirmation_email: @user.email_address, confirmation_acknowledgement: "1" }
  end
end
