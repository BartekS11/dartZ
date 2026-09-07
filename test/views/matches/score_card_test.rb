require "test_helper"

class ScoreCardTest < ActionView::TestCase
  [ :en, :pl ].each do |locale|
    [ true, false ].each do |active|
      test "#{locale} #{active ? 'active' : 'inactive'} player has labeled stats below score" do
        I18n.with_locale(locale) do
          render_score_card(active: active, last_total: 60)

          assert_select ".match-score-card.is-active", count: active ? 1 : 0
          assert_select ".match-score-main-row .match-score-quick-stats", count: 0
          assert_select ".match-score-main-row + dl.match-score-quick-stats" do
            assert_select "dt", text: I18n.t("live_match.last_throw")
            assert_select "dd", text: "60"
            assert_select "dt", text: I18n.t("stats.three_dart_average")
            assert_select ".match-score-average dd", text: "48.3"
          end
          assert_select ".match-score-quick-stats + .match-score-meta"
        end
      end
    end
  end

  test "last throw uses a dash before any completed turn" do
    render_score_card(last_total: nil)
    assert_select ".match-score-stat:first-child dd", text: "—"
  end

  test "last throw preserves zero" do
    render_score_card(last_total: 0)
    assert_select ".match-score-stat:first-child dd", text: "0"
  end

  private
    def render_score_card(active: true, last_total:)
      player = stub(id: 1, display_name: "Alice")
      match = stub(best_of_sets: 1, best_of_legs: 1, double_out?: false)
      presenter = stub(
        current_player: active ? player : nil,
        current_turn: nil,
        score_for: 501,
        sets_won_by: 0,
        legs_won_by: 0,
        last_turn_total_for: last_total,
        three_dart_average: 48.3,
        needs_double_in?: false
      )

      render partial: "matches/score_card", locals: { match: match, player: player, presenter: presenter }
    end
end
