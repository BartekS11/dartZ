require "test_helper"

class LocalizationTest < ActionDispatch::IntegrationTest
  teardown do
    I18n.locale = I18n.default_locale
  end

  test "locale is set before authentication builds its redirect" do
    get billing_path(locale: "pl")

    assert_redirected_to new_session_path(locale: "pl")
    assert_equal "pl", cookies[:locale]
  end

  test "a signed-in user preference overrides the locale cookie" do
    user = create_user("locale-preference@example.com")
    user.update!(locale: "pl")
    cookies[:locale] = "en"
    login_as(user)

    get matches_path

    assert_response :success
    assert_equal "pl", cookies[:locale]
    assert_select "html[lang='pl']"
  end

  test "explicit locale overrides and persists the user preference" do
    user = create_user("locale-explicit@example.com")
    login_as(user)

    get matches_path(locale: "pl")

    assert_response :success
    assert_equal "pl", user.reload.locale
    assert_select "html[lang='pl']"
  end

  test "unsupported locale falls back to the default" do
    cookies[:locale] = "pl"

    get matches_path(locale: "unsupported")

    assert_response :success
    assert_equal I18n.default_locale.to_s, cookies[:locale]
    assert_select "html[lang='#{I18n.default_locale}']"
  end
end
