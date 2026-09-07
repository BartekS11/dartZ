require "system_helper"

class SiteRefreshSystemTest < ApplicationSystemTestCase
  test "public pages share readable responsive surfaces in both themes and locales" do
    reset_user = create_user(unique_email("reset-design"))
    routes = {
      setup: matches_path,
      bot: new_bot_match_path,
      tournaments: tournaments_path,
      tournament_setup: new_tournament_path,
      login: new_session_path,
      register: new_registration_path,
      password: new_password_path,
      password_edit: edit_password_path(reset_user.password_reset_token),
      privacy: privacy_policy_path,
      terms: terms_of_service_path,
      contact: contact_page_path
    }

    review_pages(routes)
  end

  test "premium pages and account tools fit phones and desktop" do
    user = create_user(unique_email("site-premium"))
    user.update!(account_tier: "premium", nickname: "Design Player")
    login_user(user)
    training = user.training_sessions.create!(mode: "around_the_clock")
    tournament = Tournament.create!(title: "Friday Night Cup", format_type: "playoffs", owner_user: user)
    tournament.entries.create!(name: "Alice", seed: 1)
    tournament.entries.create!(name: "Bob", seed: 2)
    TournamentGenerator.new(tournament).call
    match = completed_match(user)
    visit practice_plans_path(locale: :en)
    click_button I18n.t("practice_plans.generate", locale: :en)
    assert_current_path %r{/practice_plans/[^/?]+}, ignore_query: true
    plan = PracticePlan.order(:created_at).last

    review_pages({
      member_setup: matches_path,
      billing: billing_path,
      stats: stats_path,
      training: training_sessions_path,
      training_play: training_session_path(training),
      practice: practice_plans_path,
      practice_detail: practice_plan_path(plan),
      results: match_path(match),
      equipment: edit_dart_setup_path,
      tournament: tournament_path(tournament),
      tournament_live: live_tournament_path(tournament)
    })

    resize(375)
    visit matches_path(locale: :en)
    find("#profileMenuButton").click
    assert_selector "#profileMenu:not(.hidden)"
    within "#profileMenu" do
      assert_link I18n.t("nav.upgrade", locale: :en)
      assert_button I18n.t("nav.logout", locale: :en)
      fill_in "user_nickname", with: "Updated Player"
      click_button I18n.t("profile.save_nickname", locale: :en)
    end
    assert_text I18n.t("flashes.profile_updated", locale: :en)
    assert_equal "Updated Player", user.reload.nickname
    find("#profileMenuButton").click
    page.driver.browser.action.send_keys(:escape).perform
    assert_selector "#profileMenu.hidden", visible: :all
    assert_equal "profileMenuButton", page.evaluate_script("document.activeElement.id")
  end

  test "invite QR keeps its white surface on phones" do
    user = create_user(unique_email("site-invite"))
    login_user(user)
    visit matches_path(locale: :en)
    fill_in "player1_name", with: "Alice"
    click_button I18n.t("matches.create_invite_match", locale: :en)
    assert_selector "[data-controller='invite-wait']"
    match = Match.order(:created_at).last
    review_pages({ invite: match_invite_path(match), invite_join: match_invite_join_path(match.invite_token) })
    visit match_invite_path(match, locale: :en)
    assert_equal "rgb(255, 255, 255)", page.evaluate_script("getComputedStyle(document.querySelector('.has-background-white')).backgroundColor")
    assert_selector ".has-background-white svg"
  end

  teardown do
    page.driver.browser.execute_cdp("Emulation.clearDeviceMetricsOverride") if E2E_ENABLED
  end

  private
    def completed_match(user)
      match = Match.create!(best_of_legs: 1, best_of_sets: 1)
      player = match.players.create!(name: "Design Player", user: user)
      match.players.create!(name: "Opponent")
      match.start_first_set!
      leg = match.current_leg
      leg.leg_players.find_by!(player: player).update!(score: 0)
      leg.update!(checkout_throws: 1)
      leg.finish!
      match.reload
    end

    def login_user(user)
      visit new_session_path(locale: :en)
      fill_in "email_address", with: user.email_address
      fill_in "password", with: "password"
      click_button I18n.t("auth.sign_in", locale: :en)
      assert_current_path root_path, ignore_query: true
    end

    def resize(width)
      page.driver.browser.execute_cdp("Emulation.setDeviceMetricsOverride",
        width: width, height: 1100, deviceScaleFactor: 1, mobile: false)
    end

    def review_pages(routes)
      [ [ 320, :pl, "light" ], [ 375, :en, "dark" ], [ 1280, :en, "dark" ], [ 1280, :pl, "light" ] ].each do |width, locale, theme|
        resize(width)
        routes.each do |name, path|
          visit "#{path}#{path.include?('?') ? '&' : '?'}locale=#{locale}"
          assert_selector "body.site-refresh .app-main .page-shell"
          unless page.evaluate_script("document.documentElement.dataset.theme") == theme
            find(".app-nav-theme-toggle").click
          end
          assert_selector "html[data-theme='#{theme}']"
          page.execute_script("document.activeElement.blur(); window.scrollTo(0, 0)")
          assert_equal width, page.evaluate_script("window.innerWidth")
          assert_equal [], overflowing_elements, "Overflow on #{name}, #{width}px, #{locale}, #{theme}"
          assert page.evaluate_script(<<~JS), "Shared card style missing on #{name}"
            Array.from(document.querySelectorAll('.theme-hero, .theme-card, .auth-card')).every(el => {
              const style = getComputedStyle(el);
              return parseFloat(style.borderTopLeftRadius) >= 12 && parseFloat(style.paddingLeft) >= 16;
            });
          JS
          assert page.evaluate_script(<<~JS), "Stats values must fit their cards on #{name}, #{width}px"
            Array.from(document.querySelectorAll('.stats-metric-card')).every(card => {
              const value = card.querySelector('.stats-metric-value');
              const bounds = card.getBoundingClientRect();
              const rect = value.getBoundingClientRect();
              return rect.left >= bounds.left && rect.right <= bounds.right && value.scrollWidth <= value.clientWidth + 1;
            });
          JS
          page.save_screenshot(Rails.root.join("tmp/screenshots/sitewide/#{name}-#{width}-#{theme}.png"))
        end
      end
    end

    def overflowing_elements
      page.evaluate_script(<<~JS)
        Array.from(document.querySelectorAll('.app-main h1, .app-main h2, .app-main input:not([type=hidden]), .app-main select, .app-main .button, .app-main .btn, .simple-nav a, .nav-utilities button, .nav-utilities select')).filter(el => {
          if (!el.getClientRects().length || el.closest('#profileMenu.hidden')) return false;
          if (el.closest('.table-container')) return false;
          const rect = el.getBoundingClientRect();
          if (rect.width <= 1 || rect.height <= 1) return false;
          return rect.left < -1 || rect.right > window.innerWidth + 1;
        }).map(el => `${el.tagName}.${el.className}: ${Math.round(el.getBoundingClientRect().left)}..${Math.round(el.getBoundingClientRect().right)}`);
      JS
    end
end
