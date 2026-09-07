require "system_helper"

class ScoreCardStatsSystemTest < ApplicationSystemTestCase
  test "both players stats stay readable and inside their cards on mobile and desktop" do
    visit matches_path(locale: :en)
    fill_in "player1_name", with: "Alice"
    fill_in "player2_name", with: "Bob"
    click_button I18n.t("matches.start_game", locale: :en)
    assert_selector ".match-score-card", count: 2
    match = Match.order(:created_at).last

    [ :en, :pl ].each do |locale|
      visit match_path(match, guest_token: match.guest_token, locale: locale)
      assert_selector ".match-score-card", count: 2

      [ 320, 375, 1280 ].each do |width|
        page.driver.browser.execute_cdp("Emulation.setDeviceMetricsOverride",
          width: width, height: 1000, deviceScaleFactor: 1, mobile: false)
        assert_equal width, page.evaluate_script("window.innerWidth")
        all(".match-score-card", count: 2).each do |card|
          within card do
            assert_selector ".match-score-quick-stats dt", text: I18n.t("live_match.last_throw", locale: locale)
            assert_selector ".match-score-quick-stats dt", text: I18n.t("stats.three_dart_average", locale: locale)
          end
        end

        assert page.evaluate_script(<<~JS), "Stats must fit below both scores at #{width}px (#{locale})"
          Array.from(document.querySelectorAll('.match-score-card')).every(card => {
            const bounds = card.getBoundingClientRect();
            const score = card.querySelector('.match-score-main-row').getBoundingClientRect();
            const stats = card.querySelector('.match-score-quick-stats').getBoundingClientRect();
            return stats.top >= score.bottom &&
              Array.from(card.querySelectorAll('.match-score-stat dt, .match-score-stat dd')).every(el => {
                const rect = el.getBoundingClientRect();
                return rect.width > 0 && rect.height > 0 &&
                  rect.left >= bounds.left - 1 && rect.right <= bounds.right + 1 &&
                  el.scrollWidth <= el.clientWidth + 1 &&
                  parseFloat(getComputedStyle(el).fontSize) >= 12;
              });
          });
        JS
      end
    end
  ensure
    page.driver.browser.execute_cdp("Emulation.clearDeviceMetricsOverride") if E2E_ENABLED
  end
end
