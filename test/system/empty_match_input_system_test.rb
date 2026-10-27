require "system_helper"

class EmptyMatchInputSystemTest < ApplicationSystemTestCase
  test "empty Enter and Submit record zero and pass play to the next player" do
    visit matches_path(locale: :en)
    fill_in "player1_name", with: "Alice"
    fill_in "player2_name", with: "Bob"
    click_button I18n.t("matches.start_game", locale: :en)
    assert_selector ".match-scoring"

    match = Match.order(:created_at).last
    first_player = match.current_leg.current_turn.player
    second_player = match.players.where.not(id: first_player.id).first
    first_turn = match.current_leg.current_turn

    find("#match-score-input").send_keys(:enter)
    assert_selector "#score-card-#{second_player.id}.is-active"
    assert first_turn.reload.completed?
    assert_equal 501, match.reload.score_for(first_player)
    assert_equal 0, first_turn.throws.sum(&:points)
    assert_field "match-score-input", with: ""

    second_turn = match.current_leg.current_turn
    click_button I18n.t("common.submit", locale: :en, default: "Submit")
    assert_selector "#score-card-#{first_player.id}.is-active"
    assert second_turn.reload.completed?
    assert_equal 501, match.reload.score_for(second_player)
    assert_equal 0, second_turn.throws.sum(&:points)
    assert_field "match-score-input", with: ""

    fill_in "match-score-input", with: "60"
    find("#match-score-input").send_keys(:enter)
    assert_selector "#score-card-#{second_player.id}.is-active"
    assert_equal 441, match.reload.score_for(first_player)
  end
end
