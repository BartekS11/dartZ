require "test_helper"

class ResultsComparisonTest < ActionView::TestCase
  User::LOCALES.each do |locale|
    test "#{locale} shows both players and all statistics without disclosure" do
      I18n.with_locale(locale) do
        render_results

        assert_select "table.results-comparison" do
          assert_select "caption", text: I18n.t("live_match.match_stats")
          assert_select "thead th[scope=col]", count: 3
          assert_select ".results-player.is-winner", text: "Alice"
          assert_select ".results-player", text: "Bob"
          assert_select "tbody tr", count: 13
          assert_select "tbody th[scope=row]", count: 13
          assert_select ".results-final-score td", text: "2"
          assert_select ".results-final-score td", text: "1"
          assert_select ".results-average td", text: "48.3"
          assert_select "td", text: "50.0%"
          assert_select "td", text: "—"
        end
        assert_select "details", count: 0
        assert_select ".translation_missing", count: 0
      end
    end
  end

  test "multi set results use sets rather than legs" do
    render_results(best_of_sets: 3)
    assert_select ".results-final-score th", text: I18n.t("live_match.sets")
    assert_select ".results-final-score td", text: "2"
    assert_select ".results-final-score td", text: "0"
  end

  test "completion without a winner does not highlight either player" do
    render_results(winner: false)
    assert_select ".results-player", count: 2
    assert_select ".is-winner", count: 0
  end

  private
    def render_results(best_of_sets: 1, winner: true)
      alice = stub(display_name: "Alice")
      bob = stub(display_name: "Bob")
      stats = {
        first_nine_avg: 60.0, darts_thrown: 30, highest_turn: 140,
        ton_plus: 2, one_forty_plus: 1, one_eighty: 0,
        checkout: { rate: 50.0, chances: 2, hits: 1, average_darts: 2.0 },
        best_leg_darts: nil
      }
      presenter = stub(players: [ alice, bob ], winner: winner ? alice : nil,
        stats_for: stats, three_dart_average: 48.3)
      presenter.stubs(:legs_won_by).with(alice).returns(2)
      presenter.stubs(:legs_won_by).with(bob).returns(1)
      presenter.stubs(:sets_won_by).with(alice).returns(2)
      presenter.stubs(:sets_won_by).with(bob).returns(0)
      match = stub(best_of_sets: best_of_sets)

      render partial: "matches/results_comparison", locals: { match: match, presenter: presenter }
    end
end
