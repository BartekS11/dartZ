require "test_helper"

class ExpandedTrainingSessionsControllerTest < ActionDispatch::IntegrationTest
  setup do
    @user = create_user("expanded-html-#{SecureRandom.hex(4)}@example.com")
    @user.update!(account_tier: "premium")
    FeatureAccess.stubs(:enabled?).returns(false)
    login_as(@user)
  end

  test "flag exposes localized modes and creates a resumable custom drill" do
    FeatureAccess.stubs(:enabled?).with(:expanded_training).returns(true)
    get training_sessions_path(locale: :pl)
    assert_response :success
    assert_select "h3", text: I18n.t("training.modes.bobs_27.name", locale: :pl)

    post training_sessions_path, params: { training_session: { mode: "custom_targets", name: "Finishes", targets: "D16, IB" } }
    session = @user.training_sessions.order(:created_at).last
    assert_redirected_to training_session_path(session, locale: :pl)
    assert_equal %w[D16 IB], session.configuration.fetch("targets")
    assert_equal "Finishes", @user.training_drills.last.name
  end

  test "expanded modes are unavailable when the flag is disabled" do
    FeatureAccess.stubs(:enabled?).with(:expanded_training).returns(false)
    post training_sessions_path, params: { training_session: { mode: "bobs_27" } }
    assert_response :not_found
  end
end
