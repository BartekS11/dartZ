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

  test "Dutch and Spanish locales are selectable and persist for signed-in users" do
    user = create_user("new-locale@example.com")
    login_as(user)

    %w[nl es].each do |locale|
      get matches_path(locale: locale)

      assert_response :success
      assert_equal locale, cookies[:locale]
      assert_equal locale, user.reload.locale
      assert_select "html[lang='#{locale}']"
    end
  end

  test "language picker uses consistent flat flag icons with accessible labels" do
    get root_path

    assert_response :success
    assert_select ".app-nav-locale-options[aria-label='Language']"
    %w[en pl nl es].each do |locale|
      assert_select "input[type=radio][name='selected_locale'][value='#{locale}'][aria-label]"
    end
    assert_select ".app-nav-locale-options > input[type=radio]", count: 2
    assert_select ".app-nav-locale-menu-panel input[type=radio]", count: 2
    assert_select "img.app-nav-locale-flag", count: 4
  end

  test "footer discloses AI-assisted Dutch and Spanish translations in every locale" do
    User::LOCALES.each do |locale|
      get root_path(locale: locale)

      assert_response :success
      assert_select ".footer-translation-note", text: I18n.t("footer.ai_translation_notice", locale: locale)
    end
  end

  test "unsupported locale falls back to the default" do
    cookies[:locale] = "pl"

    get matches_path(locale: "unsupported")

    assert_response :success
    assert_equal I18n.default_locale.to_s, cookies[:locale]
    assert_select "html[lang='#{I18n.default_locale}']"
  end
end
