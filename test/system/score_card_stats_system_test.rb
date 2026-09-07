require "system_helper"

class ScoreCardStatsSystemTest < ApplicationSystemTestCase
  test "scoring and disclosure controls still work on a phone" do
    visit matches_path(locale: :en)
    fill_in "player1_name", with: "Alice"
    fill_in "player2_name", with: "Bob"
    click_button I18n.t("matches.start_game", locale: :en)
    assert_selector ".match-scoring"
    page.driver.browser.execute_cdp("Emulation.setDeviceMetricsOverride",
      width: 375, height: 900, deviceScaleFactor: 1, mobile: false)
    match = Match.order(:created_at).last
    player = match.players.first
    score_selector = "#player-#{player.id}-score"

    click_button "T20", exact: true
    assert_selector score_selector, text: "441"
    click_button "Undo"
    assert_selector score_selector, text: "501"

    fill_in "match-score-input", with: "60"
    click_button I18n.t("common.submit", locale: :en, default: "Submit")
    assert_selector score_selector, text: "441"
    assert_selector "#score-card-#{match.players.second.id}.is-active"

    find(".match-stats-toggle summary").click
    assert_selector ".match-stats-toggle[open]"
    find(".match-dart-pad-summary").click
    assert_no_selector ".dart-btn"
    find(".match-dart-pad-summary").click
    assert_selector ".dart-btn", count: 63
  ensure
    page.driver.browser.execute_cdp("Emulation.clearDeviceMetricsOverride") if E2E_ENABLED
  end

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

      [ 320, 375, 768, 1280 ].each do |width|
        page.driver.browser.execute_cdp("Emulation.setDeviceMetricsOverride",
          width: width, height: 1000, deviceScaleFactor: 1, mobile: false)
        assert_equal width, page.evaluate_script("window.innerWidth")
        assert_selector ".match-scoring .match-score-card.is-active", count: 1
        assert_selector "label[for='match-score-input']", text: I18n.t("live_match.input", locale: locale).upcase
        assert page.evaluate_script(<<~JS), "Scores and controls must fit at #{width}px (#{locale})"
          (() => {
            const cards = Array.from(document.querySelectorAll('.match-score-card')).map(el => el.getBoundingClientRect());
            const controls = Array.from(document.querySelectorAll('.dart-btn, .match-score-submit, .btn-undo, #match-score-input'));
            return Math.abs(cards[0].top - cards[1].top) < 1 && cards[0].right <= cards[1].left + 1 &&
              document.documentElement.scrollWidth <= window.innerWidth &&
              controls.every(el => {
                const rect = el.getBoundingClientRect();
                return rect.height >= 44 && rect.width >= 44 && rect.left >= 0 && rect.right <= window.innerWidth;
              });
          })();
        JS
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
        if locale == :en && [ 375, 1280 ].include?(width)
          page.execute_script("document.activeElement.blur(); window.scrollTo(0, 0)")
          page.save_screenshot(Rails.root.join("tmp/screenshots/live-match-#{width}.png"))
        end
      end
    end
  ensure
    page.driver.browser.execute_cdp("Emulation.clearDeviceMetricsOverride") if E2E_ENABLED
  end
end
