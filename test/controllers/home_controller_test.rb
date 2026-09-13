require "test_helper"

class HomeControllerTest < ActionDispatch::IntegrationTest
  test "guest landing prioritizes play and account actions" do
    get root_path

    assert_response :success
    assert_select "a", text: I18n.t("home.play_now")
    assert_select "a[href='#{matches_path}']", minimum: 1
    assert_select "a", text: I18n.t("home.create_account"), minimum: 1
    assert_select "a", text: I18n.t("home.login"), minimum: 1
  end

  test "signed in landing replaces guest actions with match history" do
    user = create_user("landing-member@example.com")
    post session_path, params: { email_address: user.email_address, password: "password" }

    get root_path

    assert_response :success
    assert_select ".landing-user-name", text: user.display_name
    assert_select "a", text: I18n.t("home.your_matches"), minimum: 1
    assert_select ".landing-hero a", text: I18n.t("home.create_account"), count: 0
  end
end
