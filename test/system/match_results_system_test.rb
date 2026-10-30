require "system_helper"

class MatchResultsSystemTest < ApplicationSystemTestCase
  test "finished match compares players side by side at phone and desktop widths" do
    visit matches_path(locale: :en)
    fill_in "player1_name", with: "AlexandertheUnbreakableChampion"
    fill_in "player2_name", with: "Bob the persistent challenger"
    click_button I18n.t("matches.start_game", locale: :en)
    assert_selector ".match-scoring"
    match = Match.order(:created_at).last
    winner = match.players.first
    leg = match.current_leg
    leg.update!(winner: winner, checkout_throws: 2, finished_at: Time.current)
    leg.match_set.update!(winner: winner, finished_at: Time.current)
    match.update!(winner: winner, finished_at: Time.current)

    User::LOCALES.each do |locale|
      visit match_path(match, guest_token: match.guest_token, locale: locale)
      assert_selector ".results-comparison tbody tr", count: 13
      assert_no_selector ".results-comparison details"
      assert_no_selector "#match-score-input"
      assert_selector ".results-player.is-winner", text: winner.display_name

      [ 320, 375, 768, 1280 ].each do |width|
        page.driver.browser.execute_cdp("Emulation.setDeviceMetricsOverride",
          width: width, height: 1000, deviceScaleFactor: 1, mobile: false)
        assert_equal width, page.evaluate_script("window.innerWidth")
        assert page.evaluate_script(<<~JS), "Results must stay side by side and fit at #{width}px (#{locale})"
          (() => {
            const table = document.querySelector('.results-comparison');
            const headings = Array.from(table.querySelectorAll('.results-player')).map(el => el.getBoundingClientRect());
            return document.documentElement.scrollWidth <= window.innerWidth &&
              Math.abs(headings[0].top - headings[1].top) < 1 &&
              headings[0].right < headings[1].left &&
              Array.from(table.querySelectorAll('th, td')).every(el => {
                const rect = el.getBoundingClientRect();
                return rect.width > 0 && rect.left >= 0 && rect.right <= window.innerWidth &&
                  el.scrollWidth <= el.clientWidth + 1 &&
                  parseFloat(getComputedStyle(el).fontSize) >= 12;
              });
          })();
        JS
        if locale == :en && [ 375, 1280 ].include?(width)
          page.save_screenshot(Rails.root.join("tmp/screenshots/match-results-#{width}.png"))
        end
      end
    end
  ensure
    page.driver.browser.execute_cdp("Emulation.clearDeviceMetricsOverride") if E2E_ENABLED
  end
end
