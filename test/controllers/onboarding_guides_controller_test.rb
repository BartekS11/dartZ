require "test_helper"

class OnboardingGuidesControllerTest < ActionDispatch::IntegrationTest
  test "guest landing renders localized interactive guide and reopening control" do
    get root_path

    assert_response :success
    assert_select '[role="dialog"][aria-modal="true"]'
    assert_select '[data-onboarding-guide-target="reopen"]', text: I18n.t("onboarding.open")
    assert_select 'input[type="checkbox"]', count: 1
    assert_select '[data-controller="onboarding-guide"]'
    assert_select '[data-onboarding-guide-target="back"]:not([hidden])'
    assert_select '[data-onboarding-guide-target="next"]', text: I18n.t("onboarding.next")
    assert_includes response.body, I18n.t("onboarding.steps.start.title")
    guide_data = Nokogiri::HTML(response.body).at_css('[data-controller="onboarding-guide"]')
    steps = JSON.parse(guide_data["data-steps"])
    assert_equal 4, steps.length
    assert_equal true, steps[2]["new_tab"]
  end

  test "signed in user can mark current guide version complete" do
    user = create_user("onboarding-member@example.com")
    post session_path, params: { email_address: user.email_address, password: "password" }

    patch onboarding_guide_path, params: { onboarding_guide: { version: 1 } }, as: :json

    assert_response :no_content
    assert_equal 1, user.reload.onboarding_guide_version
  end

  test "guided match setup renders setup walkthrough steps" do
    get matches_path(onboarding: "setup")

    assert_response :success
    assert_select '[data-onboarding-guide-setup-mode-value="true"]'
    assert_includes response.body, I18n.t("onboarding.setup.players.title")
    assert_includes response.body, I18n.t("onboarding.setup.start.title")
    guide_data = Nokogiri::HTML(response.body).at_css('[data-controller="onboarding-guide"]')
    assert_equal 4, JSON.parse(guide_data["data-setup-steps"]).length
  end

  test "tour continuation resumes on the home page after match setup" do
    get root_path(onboarding: "continue")

    assert_response :success
    assert_select '[data-onboarding-guide-continue-mode-value="true"]'
  end

  test "guest cannot update account onboarding state" do
    patch onboarding_guide_path, params: { onboarding_guide: { version: 1 } }, as: :json

    assert_redirected_to new_session_path
  end

  test "completion version cannot be rolled back" do
    user = create_user("onboarding-version@example.com")
    user.update!(onboarding_guide_version: 2)
    post session_path, params: { email_address: user.email_address, password: "password" }

    patch onboarding_guide_path, params: { onboarding_guide: { version: 1 } }, as: :json

    assert_response :no_content
    assert_equal 2, user.reload.onboarding_guide_version
  end
end
