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

  test "landing exposes localized search and social metadata without tracking parameters" do
    I18n.available_locales.each do |locale|
      get root_path(locale: locale, utm_source: "seo-test")

      assert_response :success
      title = I18n.t("meta.title", locale: locale, app_name: "DartZ")
      description = I18n.t("meta.description", locale: locale)
      canonical = root_url(locale: locale == I18n.default_locale ? nil : locale)

      assert_select "html[lang=?]", locale.to_s
      assert_select "title", text: title
      assert_select "meta[name='description'][content=?]", description
      assert_select ".landing-copy p", text: description
      assert_select "h1", count: 1
      assert_select "link[rel='canonical'][href=?]", canonical
      assert_select "meta[property='og:url'][content=?]", canonical
      assert_select "meta[property='og:title'][content=?]", title
      assert_select "meta[property='og:description'][content=?]", description
      assert_select "meta[name='twitter:card'][content='summary']"
      assert_select "meta[name='twitter:title'][content=?]", title
      I18n.available_locales.each do |alternate|
        url = root_url(locale: alternate == I18n.default_locale ? nil : alternate)
        assert_select "link[rel='alternate'][hreflang=?][href=?]", alternate.to_s, url
      end
      assert_select "link[hreflang='x-default'][href=?]", root_url(locale: nil)
    end
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
